#include "lute/debuginternals.h"

#include "lute/common.h"
#include "lute/ref.h"
#include "lute/require.h"
#include "lute/requirevfs.h"

#include "Luau/Compiler.h"
#include "Luau/DenseHash.h"
#include "Luau/FileUtils.h"
#include "Luau/StringUtils.h"

#include "lua.h"
#include "lualib.h"

#include <cstddef>
#include <fstream>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <tuple>
#include <unordered_map>
#include <vector>

#include "lstate.h"

namespace debug
{
Breakpoint::Breakpoint(int id, std::string sourcePath, int line, BreakpointConfig config, BreakpointStatus status)
    : id(id)
    , sourcePath(sourcePath)
    , line(line)
    , condition(config.condition)
    , hitCondition(config.hitCondition)
    , logMessage(config.logMessage)
    , status(status)
{
}

Thread::Thread(int id, std::string name)
    : id(id)
    , name(name)
{
}

bool Thread::operator==(const Thread& other) const
{
    return id == other.id && name == other.name;
}

VariableScope::VariableScope(int variableReference, VariableScopeType type, std::string name, int threadId, int level, int luaref)
    : variableReference(variableReference)
    , type(type)
    , name(name)
    , threadId(threadId)
    , level(level)
    , luaref(luaref)
{
}

VariableScope VariableScope::makeLocals(int variableReference, int threadId, int level)
{
    return VariableScope(variableReference, VariableScopeType::Locals, "Locals", threadId, level, -1);
}

VariableScope VariableScope::makeUpvalues(int variableReference, int threadId, int level)
{
    return VariableScope(variableReference, VariableScopeType::Upvalues, "Upvalues", threadId, level, -1);
}

VariableScope VariableScope::makeTable(int variableReference, int luaref)
{
    return VariableScope(variableReference, VariableScopeType::Table, "Table", -1, -1, luaref);
}

bool Variable::isTrue()
{
    return value != "false" && value != "nil" && type != "void";
}

Target::Target(Runtime& parentRuntime)
    : parentRuntime(parentRuntime)
    , loadedSources("")
{
}

Target::~Target()
{
    // We want to stop the runtime so nothing runs while we are destroying the target but first
    // we need to clear all sources (which are stored as refs in the runtime).
    loadedSources.clear();
    stoppedThreadRef = nullptr;
    scriptThreadRef = nullptr;
    // this interrupts execution of runToCompletion() in order to stop
    // any infinite/long-running coroutines.
    if (launched)
    {
        childRuntime->continueDebug();
        lua_Callbacks* cb = lua_callbacks(childRuntime->GL);
        cb->interrupt = [](lua_State* L, int gc)
        {
            if (gc != -1)
                return;
            lua_break(L);
        };
    }
    childRuntime.reset();
}

static std::string getChunkFromSource(const std::string& sourcePath)
{
    return '@' + sourcePath;
}

static std::string getSourceFromChunk(const std::string& chunkname)
{
    if (chunkname.rfind('@', 0) == 0)
        return chunkname.substr(1);
    return chunkname;
}

Breakpoint Target::setBreakpoint(std::string sourcePath, int line, BreakpointConfig config)
{
    std::unique_lock lock(targetMutex);
    sourcePath = normalizePath(sourcePath);
    std::optional<Breakpoint> preexistingBp = getBreakpointBySourceLineHelper(sourcePath, line);
    if (preexistingBp)
        return *preexistingBp;
    int id = currentBreakpointId;
    currentBreakpointId++;
    auto [it, _] = breakpoints.insert_or_assign(id, Breakpoint{id, sourcePath, line, config, BreakpointStatus::PendingInstall});
    // We schedule breakpoint installs to happen when the runtime exists and we are paused. Otherwise,
    // they are scheduled for pending installs.
    if (childRuntime && paused)
    {
        installBreakpoint(childRuntime->GL, it->second);
        Breakpoint bpCopy = it->second;
        lock.unlock();
        if (bpCopy.status != BreakpointStatus::PendingInstall && launchConfig.onBreakpointInstall)
            launchConfig.onBreakpointInstall(bpCopy);
        return bpCopy;
    }
    return it->second;
}

bool Target::removeBreakpoint(int bpId)
{
    std::unique_lock lock(targetMutex);
    auto it = breakpoints.find(bpId);
    if (it == breakpoints.end())
        return false;
    Breakpoint& bp = it->second;
    if (bp.status == BreakpointStatus::PendingUninstall)
    {
        return false;
    }
    else if (bp.status == BreakpointStatus::Installed)
    {
        // We schedule breakpoint uninstalls to happen async
        if (childRuntime)
        {
            if (!paused)
            {
                bp.status = BreakpointStatus::PendingUninstall;
            }
            else
            {
                bool successful = uninstallBreakpoint(childRuntime->GL, bp);
                if (!successful)
                {
                    return false;
                }
                Breakpoint bpCopy = bp;
                breakpoints.erase(it);
                lock.unlock();
                if (launchConfig.onBreakpointUninstall)
                    launchConfig.onBreakpointUninstall(bpCopy);
            }
        }
        else
        {
            parentRuntime.reporter.reportError(
                Luau::format("breakpoint %d installed at line %d in %s is missing a runtime", bp.id, bp.line, bp.sourcePath.c_str())
            );
        }
    }
    else
    {
        // We can simply erase breakpoints that are pending or invalid
        // since they can never be hit.
        breakpoints.erase(it);
    }
    return true;
}

std::vector<Breakpoint> Target::getBreakpoints() const
{
    std::unique_lock lock(targetMutex);
    std::vector<Breakpoint> all;
    all.reserve(breakpoints.size());
    for (auto& [_, bp] : breakpoints)
        all.emplace_back(bp);
    return all;
}

std::vector<Breakpoint> Target::getBreakpointsByStatus(BreakpointStatus status) const
{
    std::unique_lock lock(targetMutex);
    std::vector<Breakpoint> statusBps;
    statusBps.reserve(breakpoints.size());
    for (auto& [_, bp] : breakpoints)
        if (bp.status == status)
            statusBps.emplace_back(bp);
    return statusBps;
}

std::optional<Breakpoint> Target::getBreakpointByIdHelper(int breakpointId) const
{
    auto it = breakpoints.find(breakpointId);
    if (it != breakpoints.end())
        return it->second;
    return std::nullopt;
}

std::optional<Breakpoint> Target::getBreakpointById(int breakpointId) const
{
    std::unique_lock lock(targetMutex);
    return getBreakpointByIdHelper(breakpointId);
}

std::optional<Breakpoint> Target::getBreakpointBySourceLineHelper(std::string source, int line) const
{
    auto it = std::find_if(
        breakpoints.begin(),
        breakpoints.end(),
        [&source, line](const std::pair<const int, Breakpoint>& entry)
        {
            return entry.second.sourcePath == source && entry.second.line == line;
        }
    );
    if (it == breakpoints.end())
        return std::nullopt;
    return it->second;
}

std::optional<Breakpoint> Target::getBreakpointBySourceLine(std::string source, int line) const
{
    std::unique_lock lock(targetMutex);
    source = normalizePath(source);
    return getBreakpointBySourceLineHelper(source, line);
}

bool Target::installBreakpoint(lua_State* L, Breakpoint& bp)
{
    auto chunkRef = loadedSources.find(bp.sourcePath);
    if (!chunkRef)
        return false;
    (*chunkRef)->push(L);
    int installedLine = lua_breakpoint(L, -1, bp.line, 1);
    lua_pop(L, 1);
    if (installedLine == -1)
    {
        bp.status = BreakpointStatus::Invalid;
        bp.line = -1;
        return false;
    }
    bp.status = BreakpointStatus::Installed;
    bp.line = installedLine;
    return true;
}

// uninstallBreakpoint does not actually remove from the breakpoint map
// to prevent issues with map iteration so callers should remember to do this.
bool Target::uninstallBreakpoint(lua_State* L, Breakpoint& bp)
{
    auto chunkRef = loadedSources.find(bp.sourcePath);
    if (!chunkRef)
    {
        parentRuntime.reporter.reportError(
            Luau::format(
                "breakpoint %d installed at line %d in %s that is queued for uninstall is missing a loaded source",
                bp.id,
                bp.line,
                bp.sourcePath.c_str()
            )
        );
        return false;
    }
    (*chunkRef)->push(L);
    int removed_line = lua_breakpoint(L, -1, bp.line, 0);
    lua_pop(L, 1);
    if (removed_line == -1)
    {
        parentRuntime.reporter.reportError(
            Luau::format(
                "breakpoint %d installed at line %d in %s that is queued for uninstall could not be removed", bp.id, bp.line, bp.sourcePath.c_str()
            )
        );
        return false;
    }
    return true;
}

// This returns the list of installed and uninstalled vectors for use in callbacks
// later.
std::pair<std::vector<Breakpoint>, std::vector<Breakpoint>> Target::modifyPendingBreakpoints(lua_State* L)
{
    std::vector<Breakpoint> installedBpsCallback;
    std::vector<Breakpoint> uninstalledBpsCallback;
    std::vector<int> toErase;
    for (auto& [id, bp] : breakpoints)
    {
        if (bp.status == BreakpointStatus::PendingInstall)
        {
            installBreakpoint(L, bp);
            if (bp.status != BreakpointStatus::PendingInstall && launchConfig.onBreakpointInstall)
                installedBpsCallback.emplace_back(bp);
        }
        if (bp.status == BreakpointStatus::PendingUninstall)
        {
            if (uninstallBreakpoint(L, bp))
            {
                if (launchConfig.onBreakpointUninstall)
                    uninstalledBpsCallback.emplace_back(bp);
                toErase.emplace_back(bp.id);
            }
        }
    }
    for (int id : toErase)
        breakpoints.erase(id);
    return {installedBpsCallback, uninstalledBpsCallback};
}

ExceptionBreakpointInfo Target::setExceptionBreakpoint(bool caught, bool uncaught)
{
    exceptionBpInfo.caughtExceptions = caught;
    exceptionBpInfo.uncaughtExceptions = uncaught;
    return exceptionBpInfo;
}

std::vector<std::string> Target::getLoadedSources()
{
    std::unique_lock lock(targetMutex);
    std::vector<std::string> sources;
    sources.reserve(loadedSources.size());
    for (auto& [path, _] : loadedSources)
        sources.emplace_back(path);
    return sources;
}

std::optional<std::pair<std::string, int>> Target::getStoppedLocation() const
{
    std::unique_lock lock(targetMutex);
    if (!launched || !paused)
        return std::nullopt;
    return std::make_pair(stoppedLocation, stoppedLine);
}

void Target::computeStoppedLocation(lua_State* L)
{
    lua_Debug info = {};
    if (!lua_getinfo(L, 0, "sl", &info))
        return;
    stoppedLine = info.currentline;
    stoppedPc = L->ci->savedpc;
    if (info.source)
        stoppedLocation = getSourceFromChunk(info.source);
    else
        stoppedLocation = "";
}

void Target::stoppedHelper(lua_State* L)
{
    paused = true;
    childRuntime->stopDebug();
    computeStoppedLocation(L);
    stoppedThread = L;
    stoppedThreadRef = getRefForThread(L);
    // Clear out stepping and pausing when this happens.
    lua_callbacks(L)->debugstep = nullptr;
    lua_callbacks(L)->interrupt = nullptr;
}

std::optional<std::string> Target::launch(std::string sourcePath, const std::vector<std::string>& args, LaunchConfig config)
{
    std::vector<Breakpoint> installedBps;
    std::vector<Breakpoint> uninstalledBps;
    {
        std::scoped_lock lock(targetMutex);
        sourcePath = normalizePath(sourcePath);
        // launch() cannot be called twice from the same target, so we assert in
        // debug mode and return false when we are in release mode.
        LUTE_ASSERT(!launched);
        if (launched)
            return "target already launched";
        childRuntime = std::make_unique<Runtime>(parentRuntime.reporter, true);
        // Set up require system before launch.
        Luau::CompileOptions debugOptions;
        debugOptions.optimizationLevel = 1;
        debugOptions.debugLevel = 2;
        std::function<void(lua_State * L, const std::string& chunkName)> onChunkLoad = [this](lua_State* ML, const std::string& chunkName)
        {
            std::string source = getSourceFromChunk(chunkName);
            std::vector<Breakpoint> installed;
            std::vector<Breakpoint> uninstalled;
            {
                std::scoped_lock lock(targetMutex);
                // this strips the potential leading @ from the chunkName for consistency when returning to DAP
                loadedSources[source] = std::make_shared<Ref>(ML, -1);
                std::tie(installed, uninstalled) = modifyPendingBreakpoints(ML);
            }
            for (auto& bp : installed)
                launchConfig.onBreakpointInstall(bp);
            for (auto& bp : uninstalled)
                launchConfig.onBreakpointUninstall(bp);
        };
        requireCtx = std::make_unique<RequireCtx>(std::make_unique<RequireVfs>(), debugOptions, onChunkLoad);
        launchConfig = config;
        setupState(
            *childRuntime,
            [this](lua_State* L)
            {
                luaopen_require(L, requireConfigInit, requireCtx.get());
                if (launchConfig.onPrint)
                {
                    lua_pushcfunction(childRuntime->GL, replacePrint, "print");
                    lua_setglobal(childRuntime->GL, "print");
                }
            }
        );

        std::ifstream file(sourcePath);
        if (!file.is_open())
        {
            childRuntime.reset();
            return Luau::format("could not open file: %s", sourcePath.c_str());
        }
        std::string source((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
        std::string bytecode = Luau::compile(source, debugOptions);
        lua_State* thread = lua_newthread(childRuntime->GL);
        luaL_sandboxthread(thread);

        std::string chunkname = getChunkFromSource(sourcePath);
        if (luau_load(thread, chunkname.c_str(), bytecode.c_str(), bytecode.size(), 0) != 0)
        {
            std::string error = lua_tostring(thread, -1);
            childRuntime.reset();
            return error;
        }
        loadedSources[sourcePath] = std::make_shared<Ref>(thread, -1);

        std::tie(installedBps, uninstalledBps) = modifyPendingBreakpoints(thread);
        for (const std::string& arg : args)
            lua_pushstring(thread, arg.c_str());
        // thread initialization
        threadIdToState.insert_or_assign(threadId, thread);
        stateToThread.insert_or_assign(thread, Thread(threadId, "Main Coroutine"));
        threadId++;

        scriptThread = thread;
        scriptThreadRef = getRefForThread(scriptThread);
        childRuntime->runningThreads.push_back({true, scriptThreadRef, static_cast<int>(args.size())});
        lua_pop(childRuntime->GL, 1);
        lua_Callbacks* cb = lua_callbacks(childRuntime->GL);
        cb->userdata = this;
        installBpHitCallback();
        installExitCallback();
        installThreadCallback();
        installExceptionCallback();

        // All VM setup happens synchronously before runContinuously starts the background thread.
        // The no-op schedule wakes the event loop so it picks up the queued thread.
        paused = false;
        launched = true;
        childRuntime->schedule([]() {});
        childRuntime->runContinuously();
    }
    for (auto& bp : installedBps)
        launchConfig.onBreakpointInstall(bp);
    for (auto& bp : uninstalledBps)
        launchConfig.onBreakpointUninstall(bp);
    return std::nullopt;
}

std::string convertHitConditionToExpression(int hitCount, std::string hitExpression)
{
    size_t start = hitExpression.find_first_not_of(" \t");
    if (start == std::string::npos)
        return "true";
    hitExpression = hitExpression.substr(start);
    size_t end = hitExpression.find_last_not_of(" \t");
    hitExpression = hitExpression.substr(0, end + 1);
    std::string hitString = std::to_string(hitCount);
    if (std::all_of(hitExpression.begin(), hitExpression.end(), ::isdigit))
        return hitString + " == " + hitExpression;
    if (hitExpression.size() > 0 && hitExpression[0] == '%')
    {
        hitExpression = hitExpression.substr(hitExpression.find_first_not_of(" \t", 1));
        if (std::all_of(hitExpression.begin() + 1, hitExpression.end(), ::isdigit))
            return hitString + "%" + hitExpression + " == 0";
    }
    return hitString + hitExpression;
}

bool Target::evaluateBpCondition(lua_State* L, const Breakpoint& bp)
{
    EvaluateResult result = evaluateExpressionHelper(L, 0, bp.condition);
    if (std::holds_alternative<std::string>(result))
    {
        parentRuntime.reporter.reportError(
            Luau::format("cannot evaluate breakpoint condition %s at line %d in %s", bp.condition.c_str(), bp.line, bp.sourcePath.c_str())
        );
        return false;
    }
    Variable var = std::get<Variable>(result);
    return var.isTrue();
}

bool Target::evaluateBpHitCondition(lua_State* L, const Breakpoint& bp)
{
    std::string hitExpression = convertHitConditionToExpression(bp.hitCount, bp.hitCondition);
    EvaluateResult result = evaluateExpressionHelper(L, 0, hitExpression);
    if (std::holds_alternative<std::string>(result))
    {
        parentRuntime.reporter.reportError(
            Luau::format(
                "cannot evaluate breakpoint hit condition %s with %d hits at line %d in %s",
                bp.hitCondition.c_str(),
                bp.hitCount,
                bp.line,
                bp.sourcePath.c_str()
            )
        );
        return false;
    }
    Variable var = std::get<Variable>(result);
    return var.isTrue();
}

std::string Target::evaluateLogMessage(lua_State* L, const Breakpoint& bp)
{
    std::string logMessage = bp.logMessage;
    size_t start;
    while ((start = logMessage.find('{')) != std::string::npos)
    {
        size_t end = logMessage.find('}', start);
        if (end == std::string::npos)
        {
            break;
        }
        std::string interpolateExpr = logMessage.substr(start + 1, end - start - 1);
        EvaluateResult result = evaluateExpressionHelper(L, 0, interpolateExpr);
        if (std::holds_alternative<std::string>(result))
        {
            parentRuntime.reporter.reportError(
                Luau::format("cannot evaluate log point message %s at line %d in %s", logMessage.c_str(), bp.line, bp.sourcePath.c_str())
            );
            return logMessage;
        }
        Variable var = std::get<Variable>(result);
        logMessage.replace(start, end - start + 1, var.value);
    }
    return logMessage + '\n';
}

void Target::installBpHitCallback()
{
    lua_Callbacks* cb = lua_callbacks(childRuntime->GL);
    cb->debugbreak = [](lua_State* L, lua_Debug* ar)
    {
        auto target = static_cast<Target*>(lua_callbacks(L)->userdata);
        // We land on the same instruction after a continue() after hitting a bp so we basically don't do anything
        std::unique_lock lock(target->targetMutex);
        if (auto it = target->continueRequestedBp.find(L); it != target->continueRequestedBp.end())
        {
            target->continueRequestedBp.erase(it);
            return;
        }
        lua_Debug info = {};
        lua_getinfo(L, 0, "s", &info);
        target->stoppedLine = ar->currentline;
        int line = ar->currentline;
        if (!info.source)
        {
            target->parentRuntime.reporter.reportError(Luau::format("breakpoint hit at line %d could not find a runtime source", line));
            return;
        }
        target->stoppedPc = L->ci->savedpc;
        std::string chunkname = info.source;
        std::optional<Breakpoint> bp = target->getBreakpointBySourceLineHelper(getSourceFromChunk(chunkname), line);
        // Only stop execution on installed breakpoints; otherwise, don't stop.
        if (bp && bp->status == BreakpointStatus::Installed)
        {
            target->breakpoints.at(bp->id).hitCount++;
            bp->hitCount = target->breakpoints.at(bp->id).hitCount;
            if (bp->condition != "" && !target->evaluateBpCondition(L, *bp))
            {
                return;
            }
            if (bp->hitCondition != "" && !target->evaluateBpHitCondition(L, *bp))
            {
                return;
            }
            if (bp->logMessage != "")
            {
                lock.unlock();
                std::string message = target->evaluateLogMessage(L, *bp);
                if (target->launchConfig.onLogpointHit)
                    target->launchConfig.onLogpointHit(message, bp.value());
                return;
            }
            target->bpHit = *bp;
            target->stoppedHelper(L);
            lua_break(L);
            auto [installed, uninstalled] = target->modifyPendingBreakpoints(target->scriptThread);
            Thread thread = target->stateToThread.at(L);
            lock.unlock();
            if (target->launchConfig.onBreakpointHit)
                target->launchConfig.onBreakpointHit(thread, bp.value());
            for (auto& bp : installed)
                target->launchConfig.onBreakpointInstall(bp);
            for (auto& bp : uninstalled)
                target->launchConfig.onBreakpointUninstall(bp);
        }
        else if (!bp || bp->status != BreakpointStatus::PendingUninstall)
        {
            // It is normal to hit breakpoints that are pending uninstall but not normal
            // to hit any other type of breakpoint so we error in those cases.
            target->parentRuntime.reporter.reportError(
                Luau::format("breakpoint hit at line %d in %s could not be found in breakpoint map", line, chunkname.c_str())
            );
        }
    };
}

// When the main script's coroutine exits, we can say that our debugging of the debuggee has terminated.
// Theoretically, the debuggee can still be alive on the Runtime but should be cleaned up after
// the Target itself is destroyed.
void Target::installExitCallback()
{
    ThreadCompletionHandler completion;
    completion.onFinish = [this](lua_State* L, int status)
    {
        if (launchConfig.onExit)
            launchConfig.onExit(status == LUA_OK);
    };
    childRuntime->addThreadCompletionHandler(scriptThread, std::move(completion));
}

int Target::replacePrint(lua_State* L)
{
    Target* target = static_cast<Target*>(lua_callbacks(L)->userdata);
    std::string msg = "";
    int n = lua_gettop(L);
    for (int i = 1; i <= n; i++)
    {
        if (i > 1)
            msg += "\t";
        const char* s = luaL_tolstring(L, i, nullptr);
        if (s)
            msg += s;
        lua_pop(L, 1);
    }
    msg += '\n';
    lua_Debug ar;
    lua_getinfo(L, 1, "sl", &ar);
    if (target && target->launchConfig.onPrint)
    {
        std::string source;
        if (ar.source)
            source = getSourceFromChunk(ar.source);
        else
            source = "";
        target->launchConfig.onPrint(msg, source, ar.currentline);
    }
    return 0;
}

void Target::installThreadCallback()
{
    lua_Callbacks* cb = lua_callbacks(childRuntime->GL);
    cb->userthread = [](lua_State* LP, lua_State* L)
    {
        auto target = static_cast<Target*>(lua_callbacks(L)->userdata);
        std::unique_lock lock(target->targetMutex);

        // this means a thread is being garbage collected
        if (LP == nullptr)
        {
            // we can have unregistered threads such as eval threads that still get GC'ed.
            if (auto it = target->stateToThread.find(L); it != target->stateToThread.end())
            {
                int id = it->second.id;
                target->stateToThread.erase(it);
                if (target->threadIdToState.erase(id) == 0)
                {
                    target->parentRuntime.reporter.reportError(Luau::format("userthread callback fired for unregistered thread id %d", id));
                }
            }
        }
        else
        {
            target->threadIdToState.insert_or_assign(target->threadId, L);
            target->stateToThread.insert_or_assign(L, Thread(target->threadId, "Coroutine " + std::to_string(target->threadId)));
            target->threadId++;
        }
    };
}

void Target::installExceptionCallback()
{
    childRuntime->onUncaughtError = [](lua_State* L)
    {
        auto target = static_cast<Target*>(lua_callbacks(L)->userdata);
        std::unique_lock lock(target->targetMutex);
        if (!target->exceptionBpInfo.uncaughtExceptions)
            return false;
        target->stoppedHelper(L);
        target->stoppedUncaughtException = true;
        Thread thread = target->stateToThread.at(L);
        const char* s = luaL_tolstring(L, -1, nullptr);
        std::string errorMessage = s ? s : "unknown error";
        lua_pop(L, 1);
        auto [installed, uninstalled] = target->modifyPendingBreakpoints(target->scriptThread);
        lock.unlock();
        for (auto& bp : installed)
            target->launchConfig.onBreakpointInstall(bp);
        for (auto& bp : uninstalled)
            target->launchConfig.onBreakpointUninstall(bp);
        if (target->launchConfig.onException)
            target->launchConfig.onException(thread, target->exceptionBpInfo.uncaughtId, errorMessage);
        return true;
    };
    lua_Callbacks* cb = lua_callbacks(childRuntime->GL);
    cb->debugprotectederror = [](lua_State* L)
    {
        auto target = static_cast<Target*>(lua_callbacks(L)->userdata);
        std::unique_lock lock(target->targetMutex);
        if (!target->exceptionBpInfo.caughtExceptions)
            return;
        target->stoppedHelper(L);
        Thread thread = target->stateToThread.at(L);
        const char* s = luaL_tolstring(L, -1, nullptr);
        std::string errorMessage = s ? s : "unknown error";
        lua_pop(L, 1);
        auto [installed, uninstalled] = target->modifyPendingBreakpoints(target->scriptThread);
        lua_break(L);
        lock.unlock();
        for (auto& bp : installed)
            target->launchConfig.onBreakpointInstall(bp);
        for (auto& bp : uninstalled)
            target->launchConfig.onBreakpointUninstall(bp);
        if (target->launchConfig.onException)
            target->launchConfig.onException(thread, target->exceptionBpInfo.caughtId, errorMessage);
    };
}

std::optional<Thread> Target::getMainThread() const
{
    std::unique_lock lock(targetMutex);
    if (!launched)
        return std::nullopt;
    return stateToThread.at(scriptThread);
}


std::optional<Thread> Target::getStoppedThread() const
{
    std::unique_lock lock(targetMutex);
    if (!launched || !paused)
        return std::nullopt;
    return stateToThread.at(stoppedThread);
}

std::vector<Thread> Target::getThreads() const
{
    std::unique_lock lock(targetMutex);
    std::vector<Thread> result;
    for (auto& [L, thread] : stateToThread)
    {
        if (L == stoppedThread || (lua_costatus(childRuntime->GL, L) != LUA_COFIN && lua_costatus(childRuntime->GL, L) != LUA_COERR))
            result.emplace_back(thread);
    }
    return result;
}

int Target::getStackDepth(int threadId)
{
    if (!launched || !paused || threadIdToState.find(threadId) == threadIdToState.end())
        return -1;
    return lua_stackdepth(threadIdToState.at(threadId));
}

std::optional<StackFrame> Target::getStackFrameHelper(int threadId, int level)
{
    if (!paused)
        return std::nullopt;
    if (threadIdToState.find(threadId) == threadIdToState.end())
        return std::nullopt;
    std::unordered_map<int, StackFrame>& levelMap = stateToStackFrame[threadId];
    auto it = levelMap.find(level);
    if (it == levelMap.end())
    {
        StackFrame frame;
        frame.id = stackframeId;
        stackframeId++;
        lua_Debug ar = {};
        lua_State* threadLua = threadIdToState.at(threadId);
        if (!lua_getinfo(threadLua, level, "sln", &ar))
            return std::nullopt;
        if (!ar.name)
            if (threadLua == scriptThread && level == lua_stackdepth(threadLua) - 1)
                frame.name = "(entry)";
            else
                frame.name = "(anonymous)";
        else
            frame.name = ar.name;
        if (ar.source)
        {
            frame.sourcePath = getSourceFromChunk(ar.source);
            // edge case: when we hit a breakpoint, the pc is sent backward one
            // so that we can hit it again, so lua_getinfo() fails.
            if (level == 0 && stoppedLine != -1)
                frame.line = stoppedLine;
            else
                frame.line = ar.currentline;
        }
        else
        {
            frame.sourcePath = "";
            frame.line = 0;
        }
        frame.column = 0;
        levelMap[level] = frame;
        idToStackFrameInfo[frame.id] = std::make_pair(threadId, level);
        return frame;
    }
    return it->second;
}

std::optional<StackFrame> Target::getStackFrame(int threadId, int level)
{
    std::unique_lock lock(targetMutex);
    return getStackFrameHelper(threadId, level);
}

std::optional<std::vector<StackFrame>> Target::getStackTrace(int threadId, int startLevel, int numFrames)
{
    std::unique_lock lock(targetMutex);
    if (!paused)
        return std::nullopt;
    if (threadIdToState.find(threadId) == threadIdToState.end())
        return std::nullopt;
    int stackDepth = lua_stackdepth(threadIdToState[threadId]);
    if (startLevel >= stackDepth)
        return std::vector<StackFrame>{};
    int maximumLevel;
    if (numFrames == 0)
        maximumLevel = stackDepth;
    else
        maximumLevel = std::min(startLevel + numFrames, stackDepth);
    std::vector<StackFrame> stackTrace;
    for (int i = startLevel; i < maximumLevel; i++)
    {
        std::optional<StackFrame> frame = getStackFrameHelper(threadId, i);
        if (!frame)
            return std::nullopt;
        stackTrace.emplace_back(*frame);
    }
    return stackTrace;
}

std::optional<std::vector<VariableScope>> Target::getScopesHelper(int threadId, int level)
{
    std::optional<StackFrame> frame = getStackFrameHelper(threadId, level);
    if (!frame)
        return std::nullopt;
    if (scopeCache.find(frame->id) != scopeCache.end())
        return scopeCache.at(frame->id);
    std::vector<VariableScope> contexts;
    VariableScope locals = VariableScope::makeLocals(variableRefId, threadId, level);
    variableContexts.insert_or_assign(variableRefId, locals);
    variableRefId++;
    contexts.push_back(locals);
    VariableScope upvalues = VariableScope::makeUpvalues(variableRefId, threadId, level);
    variableContexts.insert_or_assign(variableRefId, upvalues);
    variableRefId++;
    contexts.push_back(upvalues);
    scopeCache[frame->id] = contexts;
    return contexts;
}

std::optional<std::vector<VariableScope>> Target::getScopes(int frameId)
{
    std::unique_lock lock(targetMutex);
    if (!paused)
        return std::nullopt;
    auto it = idToStackFrameInfo.find(frameId);
    if (it == idToStackFrameInfo.end())
        return std::nullopt;
    auto [threadId, level] = it->second;
    return getScopesHelper(threadId, level);
}

static std::string convertNumberToString(lua_State* L, int stackSlot)
{
    double val = lua_tonumber(L, stackSlot);
    if (val == trunc(val))
        return std::to_string(lua_tointeger(L, stackSlot));
    char buf[64];
    snprintf(buf, sizeof(buf), "%.15g", val);
    return buf;
}

static std::string getKeyFromTableType(lua_State* L)
{
    std::string key;
    switch (lua_type(L, -2))
    {
    case LUA_TSTRING:
        key = std::string(lua_tostring(L, -2));
        break;
    case LUA_TNUMBER:
        key = "[" + convertNumberToString(L, -2) + "]";
        break;
    case LUA_TBOOLEAN:
        key = lua_toboolean(L, -2) ? "[true]" : "[false]";
        break;
    default:
        key = "[" + std::string(lua_typename(L, lua_type(L, -2))) + "]";
        break;
    }
    return key;
}

static std::string printTable(lua_State* L, int idx, int levelsToPrint)
{
    if (levelsToPrint <= 0)
        return "{...}";
    int absoluteIndex = lua_absindex(L, idx);
    std::string result = "{";
    lua_pushnil(L);
    std::vector<std::pair<std::string, std::string>> keyValues;
    while (lua_next(L, absoluteIndex))
    {
        std::string key = getKeyFromTableType(L);
        std::string value;
        switch (lua_type(L, -1))
        {
        case LUA_TNUMBER:
            value = convertNumberToString(L, -1);
            break;
        case LUA_TSTRING:
            value = "\"" + std::string(lua_tostring(L, -1)) + "\"";
            break;
        case LUA_TBOOLEAN:
            value = lua_toboolean(L, -1) ? "true" : "false";
            break;
        case LUA_TTABLE:
            value = printTable(L, -1, levelsToPrint - 1);
            break;
        default:
            value = lua_typename(L, lua_type(L, -1));
            break;
        }
        keyValues.push_back(std::make_pair(key, value));
        lua_pop(L, 1);
    }
    // this is a "pure" array
    if ((int)(keyValues.size()) == lua_objlen(L, idx))
    {
        for (auto [_, value] : keyValues)
        {
            if (result != "{")
                result += ", ";
            result += value;
        }
    }
    else
    {
        for (auto [key, value] : keyValues)
        {
            if (result != "{")
                result += ", ";
            result += key + "=" + value;
        }
    }
    return result + "}";
}

Variable Target::makeVariable(lua_State* L, const std::string& name)
{
    Variable var;
    var.name = name;
    var.type = lua_typename(L, lua_type(L, -1));
    switch (lua_type(L, -1))
    {
    case LUA_TNUMBER:
    {
        var.value = convertNumberToString(L, -1);
        break;
    }
    case LUA_TSTRING:
        var.value = "\"" + std::string(lua_tostring(L, -1)) + "\"";
        break;
    case LUA_TBOOLEAN:
        var.value = lua_toboolean(L, -1) ? "true" : "false";
        break;
    case LUA_TTABLE:
    {
        var.value = printTable(L, -1, 2);
        var.variableReference = variableRefId;
        lua_pushvalue(L, -1);
        int ref = lua_ref(L, -1);
        lua_pop(L, 1);
        variableContexts.insert_or_assign(variableRefId, VariableScope::makeTable(variableRefId, ref));
        variableRefId++;
        break;
    }
    default:
        var.value = lua_typename(L, lua_type(L, -1));
        break;
    }
    return var;
}

std::vector<Variable> Target::getLocalsHelper(lua_State* L, int level)
{
    // when hitting a bp we try to re-enter
    bool fixedSavedpc = false;
    const Instruction* original = L->ci->savedpc;
    if (level == 0 && L == stoppedThread)
    {
        L->ci->savedpc = stoppedPc;
        fixedSavedpc = true;
    }
    const char* name;
    int n = 1;
    std::vector<Variable> vars;
    while ((name = lua_getlocal(L, level, n)) != nullptr)
    {
        vars.push_back(makeVariable(L, name));
        lua_pop(L, 1);
        n++;
    }
    if (fixedSavedpc)
        L->ci->savedpc = original;
    return vars;
}

std::vector<Variable> Target::getUpvaluesHelper(lua_State* L, int level)
{
    std::vector<Variable> vars;
    lua_Debug ar = {};
    lua_getinfo(L, level, "f", &ar);
    int n = 1;
    const char* name;
    while ((name = lua_getupvalue(L, -1, n)) != nullptr)
    {
        vars.push_back(makeVariable(L, name));
        lua_pop(L, 1);
        n++;
    }
    lua_pop(L, 1);
    return vars;
}

std::vector<Variable> Target::getTableHelper(lua_State* L, int idx)
{
    std::vector<Variable> vars;
    int absoluteIndex = lua_absindex(L, idx);
    lua_pushnil(L);
    while (lua_next(L, absoluteIndex))
    {
        std::string key = getKeyFromTableType(L);
        vars.push_back(makeVariable(L, key));
        lua_pop(L, 1);
    }
    return vars;
}

std::optional<std::vector<Variable>> Target::getVariablesHelper(int varRef)
{
    auto it = variableContexts.find(varRef);
    if (it == variableContexts.end())
        return std::nullopt;
    VariableScope context = it->second;
    if (auto it2 = variableCache.find(varRef); it2 != variableCache.end())
        return it2->second;
    std::vector<Variable> vars;
    if (context.type == VariableScopeType::Locals)
    {
        vars = getLocalsHelper(threadIdToState.at(context.threadId), context.level);
    }
    else if (context.type == VariableScopeType::Upvalues)
    {
        vars = getUpvaluesHelper(threadIdToState.at(context.threadId), context.level);
    }
    else
    {
        lua_rawgeti(childRuntime->GL, LUA_REGISTRYINDEX, context.luaref);
        vars = getTableHelper(childRuntime->GL, -1);
        lua_pop(childRuntime->GL, 1);
    }
    variableCache[varRef] = vars;
    return vars;
}

std::optional<std::vector<Variable>> Target::getVariables(int varRef)
{
    std::unique_lock lock(targetMutex);
    if (!paused)
    {
        return std::nullopt;
    }
    return getVariablesHelper(varRef);
}

std::optional<std::vector<Variable>> Target::getVariablesByScopeType(int frameId, VariableScopeType contextType)
{
    std::unique_lock lock(targetMutex);
    if (!paused)
        return std::nullopt;
    auto stackFrame = idToStackFrameInfo.find(frameId);
    if (stackFrame == idToStackFrameInfo.end())
        return std::nullopt;
    auto [threadId, level] = stackFrame->second;
    std::optional<std::vector<VariableScope>> scopes = getScopesHelper(threadId, level);
    if (!scopes)
        return std::nullopt;
    auto it = std::find_if(
        scopes->begin(),
        scopes->end(),
        [&](const VariableScope& ctx)
        {
            return ctx.type == contextType;
        }
    );
    if (it == scopes->end())
    {
        return std::nullopt;
    }
    return getVariablesHelper(it->variableReference);
}

void Target::injectLocals(lua_State* L, int level, lua_State* eval, int evalTableIndex)
{
    bool fixedSavedpc = false;
    const Instruction* original = L->ci->savedpc;
    if (level == 0 && L == stoppedThread && L->ci)
    {
        L->ci->savedpc = stoppedPc;
        fixedSavedpc = true;
    }
    const char* name;
    int n = 1;
    while (true)
    {
        name = lua_getlocal(L, level, n);
        if (name == nullptr)
            break;
        lua_xmove(L, eval, 1);
        lua_setfield(eval, evalTableIndex, name);
        n++;
    }
    if (fixedSavedpc)
        L->ci->savedpc = original;
}


void Target::injectUpvalues(lua_State* L, int level, lua_State* eval, int evalTableIndex)
{
    lua_Debug ar = {};
    if (lua_getinfo(L, level, "f", &ar) == 0)
        return;
    int n = 1;
    const char* name;
    while (true)
    {
        name = lua_getupvalue(L, -1, n);
        if (name == nullptr)
            break;
        lua_xmove(L, eval, 1);
        lua_setfield(eval, evalTableIndex, name);
        n++;
    }
    lua_pop(L, 1);
}

EvaluateResult Target::evaluateExpressionHelper(lua_State* L, int level, std::string expression)
{
    struct StackGuard
    {
        lua_State* L;
        ~StackGuard()
        {
            lua_pop(L, 1);
        }
    };
    // we 1) don't want to register the eval thread to stop re-entrancy on the mutex (and to not have floating threads on the screen)
    // and consequently 2) don't want to run gc during evaluation
    struct CallbackGuard
    {
        lua_State* global;
        lua_Callbacks* cb;
        decltype(cb->userthread) savedUserthread;
        explicit CallbackGuard(lua_State* global)
            : global(global)
            , cb(lua_callbacks(global))
            , savedUserthread(cb->userthread)
        {
            lua_gc(global, LUA_GCSTOP, 0);
            cb->userthread = nullptr;
        }
        ~CallbackGuard()
        {
            cb->userthread = savedUserthread;
            lua_gc(global, LUA_GCRESTART, 0);
        }
    };
    Luau::CompileOptions debugOptions;
    debugOptions.optimizationLevel = 1;
    debugOptions.debugLevel = 2;
    std::string bytecode = Luau::compile("return " + expression, debugOptions);
    CallbackGuard callbackGuard(childRuntime->GL);
    lua_State* evalThread = lua_newthread(childRuntime->GL);
    StackGuard stackGuard{childRuntime->GL};
    luaL_sandboxthread(evalThread);
    // sets the previous global table is the top most scope of all variables
    lua_newtable(evalThread);
    lua_newtable(evalThread);
    lua_pushvalue(evalThread, LUA_GLOBALSINDEX);
    lua_setfield(evalThread, 2, "__index");
    lua_setmetatable(evalThread, 1);
    // inject locals + upvalues
    if (L != nullptr)
    {
        int depth = lua_stackdepth(L);
        for (int i = depth - 1; i >= level; i--)
        {
            injectUpvalues(L, i, evalThread, 1);
            injectLocals(L, i, evalThread, 1);
        }
    }
    lua_replace(evalThread, LUA_GLOBALSINDEX);
    if (luau_load(evalThread, "=eval", bytecode.c_str(), bytecode.size(), 0) != 0)
    {
        std::string error = lua_tostring(evalThread, -1);
        return error;
    }
    lua_Callbacks* cb = lua_callbacks(childRuntime->GL);
    auto savedBreak = cb->debugbreak;
    cb->debugbreak = nullptr;
    int status = lua_resume(evalThread, nullptr, 0);
    cb->debugbreak = savedBreak;
    if (status != LUA_OK)
    {
        const char* err = lua_tostring(evalThread, -1);
        return std::string(err ? err : "runtime error");
    }
    if (lua_gettop(evalThread) == 0)
        return Variable{expression, "(no value)", "void"};
    return makeVariable(evalThread, expression);
}

EvaluateResult Target::evaluateExpression(std::string expression, int frameId)
{
    std::unique_lock lock(targetMutex);
    if (!paused)
        return "target was not paused";
    lua_State* thread = nullptr;
    int level = -1;
    if (frameId != -1)
    {
        auto [threadId, threadLevel] = idToStackFrameInfo.at(frameId);
        thread = threadIdToState.at(threadId);
        level = threadLevel;
    }
    return evaluateExpressionHelper(thread, level, expression);
}

void Target::continueProcessHelper()
{
    // this clears the interrupts that triggers when the process is paused from client request
    // in case it has not actually been triggered.
    lua_Callbacks* cb = lua_callbacks(childRuntime->GL);
    cb->interrupt = nullptr;

    // we clear the inspect information
    stackframeId = 1;
    stateToStackFrame.clear();
    idToStackFrameInfo.clear();

    variableRefId = 1;
    for (auto& [_, scope] : variableContexts)
        if (scope.type == VariableScopeType::Table)
            lua_unref(childRuntime->GL, scope.luaref);
    scopeCache.clear();
    variableContexts.clear();
    variableCache.clear();

    if (stoppedThread)
    {
        if (!stoppedUncaughtException)
        {
            // we are continuing on a breakpoint and so might need to flag continueRequestedBp.
            if (bpHit)
            {
                // we need to check if our breakpoint is still currently installed after
                // onBreakpointHit() callback
                std::optional<Breakpoint> currentBp = getBreakpointByIdHelper(bpHit->id);
                if (currentBp && currentBp->status == BreakpointStatus::Installed)
                    continueRequestedBp.insert(stoppedThread);
                bpHit = std::nullopt;
            }
            childRuntime->runningThreads.push_back({true, stoppedThreadRef, 0});
            // This schedule() wakes up the runtime in runContinuously() to re-run runToCompletion() in case that has exited. This is a no-op if
            // runToCompletion() has not exited.
            childRuntime->schedule([]() {});
        }
        else
        {
            childRuntime->runUncaughtExceptionCompletion(stoppedThread);
            stoppedUncaughtException = false;
        }
        stoppedThread = nullptr;
        stoppedThreadRef = nullptr;
        stoppedLine = -1;
        stoppedLocation = "";
        stoppedPc = nullptr;
    }
    paused = false;
    childRuntime->continueDebug();
}

bool Target::continueProcess()
{
    std::unique_lock lock(targetMutex);
    if (!launched || !paused)
        return false;
    continueProcessHelper();
    return true;
}

bool Target::pauseProcess()
{
    std::unique_lock lock(targetMutex);
    if (!launched || paused)
        return false;
    lua_Callbacks* cb = lua_callbacks(childRuntime->GL);
    // the interrupt callback calls at any safepoint, which
    // is the soonest we can pause execution safely.
    // safepoints are loop back edges or function calls/returns.
    cb->interrupt = [](lua_State* L, int gc)
    {
        // gc runs when it is not -1
        if (gc != -1)
            return;
        auto target = static_cast<Target*>(lua_callbacks(L)->userdata);
        std::unique_lock lock(target->targetMutex);
        target->stoppedHelper(L);
        Thread thread = target->stateToThread.at(L);
        // We transition into a paused state. Let's modify all pending breakpoints.
        auto [installed, uninstalled] = target->modifyPendingBreakpoints(target->scriptThread);
        lua_break(L);
        // Clear out the interrupt and debugstep callback after we are done.
        lock.unlock();
        // Since pausing actually only happens when the interrupt callback runs we have a callback
        if (target->launchConfig.onPause)
            target->launchConfig.onPause(thread);
        for (auto& bp : installed)
            target->launchConfig.onBreakpointInstall(bp);
        for (auto& bp : uninstalled)
            target->launchConfig.onBreakpointUninstall(bp);
    };
    return true;
}

bool Target::step(int threadId, StepType type)
{
    std::unique_lock lock(targetMutex);
    if (!launched || !paused)
        return false;
    if (threadIdToState.find(threadId) == threadIdToState.end())
        return false;
    lua_State* stepThread = threadIdToState.at(threadId);
    Thread threadInfo = stateToThread.at(stepThread);
    int startLine = stoppedLine, startDepth = lua_stackdepth(stepThread);
    stepInfo = {threadInfo, type, startLine, startDepth};
    lua_singlestep(stepThread, 1);
    lua_Callbacks* cb = lua_callbacks(childRuntime->GL);
    cb->debugstep = [](lua_State* L, lua_Debug* ar)
    {
        auto target = static_cast<Target*>(lua_callbacks(L)->userdata);
        std::unique_lock lock(target->targetMutex);
        if (!target->stepInfo)
        {
            target->parentRuntime.reporter.reportError(Luau::format("target lacks stepping info even while stepping at line %d", ar->currentline));
            return;
        }
        bool stopStepping = false;
        StepInfo stepInfo = *target->stepInfo;
        if (target->threadIdToState.find(stepInfo.thread.id) == target->threadIdToState.end())
        {
            target->parentRuntime.reporter.reportError(Luau::format("could not finding stepping thread %d in thread map", stepInfo.thread.id));
            return;
        }
        lua_State* steppingThread = target->threadIdToState[stepInfo.thread.id];
        if (L != steppingThread)
            return;
        int line = ar->currentline;
        int depth = lua_stackdepth(L);
        switch (stepInfo.type)
        {
        case StepType::StepIn:
            if (line != stepInfo.startLine || depth != stepInfo.startDepth)
                stopStepping = true;
            break;
        case StepType::StepOver:
            if (depth <= stepInfo.startDepth && line != stepInfo.startLine)
                stopStepping = true;
            break;
        case StepType::StepOut:
            if (depth < stepInfo.startDepth)
                stopStepping = true;
            break;
        }
        if (stopStepping)
        {
            target->stoppedHelper(L);
            auto [installed, uninstalled] = target->modifyPendingBreakpoints(target->scriptThread);
            lua_break(L);
            lua_singlestep(L, 0);
            lua_callbacks(L)->debugstep = nullptr;
            Thread thread = target->stateToThread.at(L);
            lock.unlock();
            // Since pausing actually only happens when the step callback runs we have a callback
            if (target->launchConfig.onStepStop)
                target->launchConfig.onStepStop(thread, stepInfo);
            for (auto& bp : installed)
                target->launchConfig.onBreakpointInstall(bp);
            for (auto& bp : uninstalled)
                target->launchConfig.onBreakpointUninstall(bp);
        }
        else
        {
            return;
        }
    };
    continueProcessHelper();
    return true;
}

bool Target::stepIn(int threadId)
{
    return step(threadId, StepType::StepIn);
}

bool Target::stepOver(int threadId)
{
    return step(threadId, StepType::StepOver);
}

bool Target::stepOut(int threadId)
{
    return step(threadId, StepType::StepOut);
}
} // namespace debug
