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

namespace debug
{
Breakpoint::Breakpoint(int id, std::string sourcePath, int line, BreakpointStatus status)
    : id(id)
    , sourcePath(sourcePath)
    , line(line)
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

Breakpoint Target::setBreakpoint(std::string sourcePath, int line)
{
    std::unique_lock lock(targetMutex);
    sourcePath = normalizePath(sourcePath);
    std::optional<Breakpoint> preexistingBp = getBreakpointBySourceLineHelper(sourcePath, line);
    if (preexistingBp)
        return *preexistingBp;
    int id = currentBreakpointId;
    currentBreakpointId++;
    auto [it, _] = breakpoints.insert_or_assign(id, Breakpoint{id, sourcePath, line, BreakpointStatus::PendingInstall});
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

std::vector<std::string> Target::getLoadedSources()
{
    std::unique_lock lock(targetMutex);
    std::vector<std::string> sources;
    sources.reserve(loadedSources.size());
    for (auto& [path, _] : loadedSources)
        sources.emplace_back(path);
    return sources;
}

int Target::getLine() const
{
    std::unique_lock lock(targetMutex);
    if (!launched || !paused)
        return -1;
    return stoppedLine;
}

void Target::computeStoppedLine(lua_State* L)
{
    lua_Debug info = {};
    lua_getinfo(L, 0, "l", &info);
    stoppedLine = info.currentline;
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

void Target::installBpHitCallback()
{
    lua_Callbacks* cb = lua_callbacks(childRuntime->GL);
    cb->debugbreak = [](lua_State* L, lua_Debug* ar)
    {
        auto target = static_cast<Target*>(lua_callbacks(L)->userdata);
        std::unique_lock lock(target->targetMutex);
        // We land on the same instruction after a continue() after hitting a bp so if we have
        // already have continue() on this thread, we basically don't do anything
        if (auto it = target->continueRequestedBp.find(L); it != target->continueRequestedBp.end())
        {
            target->continueRequestedBp.erase(it);
            return;
        }
        lua_Debug info = {};
        lua_getinfo(L, 0, "s", &info);
        int line = ar->currentline;
        if (!info.source)
        {
            target->parentRuntime.reporter.reportError(Luau::format("breakpoint hit at line %d could not find a runtime source", line));
            return;
        }
        std::string chunkname = info.source;
        std::optional<Breakpoint> bp = target->getBreakpointBySourceLineHelper(getSourceFromChunk(chunkname), line);
        // Only stop execution on installed breakpoints; otherwise, don't stop.
        if (bp && bp->status == BreakpointStatus::Installed)
        {
            target->bpHit = *bp;
            target->paused = true;
            target->childRuntime->stopDebug();
            target->stoppedLine = line;
            target->stoppedThread = L;
            target->stoppedThreadRef = getRefForThread(L);
            // Clear out stepping when this happens.
            lua_callbacks(L)->debugstep = nullptr;
            lua_break(L);
            auto [installed, uninstalled] = target->modifyPendingBreakpoints(target->scriptThread);
            debug::Thread thread = target->stateToThread.at(L);
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

            if (auto it = target->stateToThread.find(L); it != target->stateToThread.end())
            {
                int id = it->second.id;
                target->stateToThread.erase(it);
                if (target->threadIdToState.erase(id) == 0)
                {
                    target->parentRuntime.reporter.reportError(Luau::format("userthread callback fired for unregistered thread id %d", id));
                }
            }
            else
            {
                target->parentRuntime.reporter.reportError(Luau::format("userthread callback fired for unregistered lua_State* %p", (void*)L));
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
        if (lua_costatus(childRuntime->GL, L) != LUA_COFIN && lua_costatus(childRuntime->GL, L) != LUA_COERR)
            result.emplace_back(thread);
    }
    return result;
}

void Target::continueProcessHelper()
{
    // this clears the interrupts that triggers when the process is paused from client request
    // in case it has not actually been triggered.
    lua_Callbacks* cb = lua_callbacks(childRuntime->GL);
    cb->interrupt = nullptr;
    if (stoppedThread)
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
        stoppedThread = nullptr;
        stoppedThreadRef = nullptr;
        stoppedLine = -1;
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
        target->paused = true;
        target->childRuntime->stopDebug();
        target->stoppedThread = L;
        target->stoppedThreadRef = getRefForThread(L);
        debug::Thread thread = target->stateToThread.at(L);
        // We transition into a paused state. Let's modify all pending breakpoints.
        auto [installed, uninstalled] = target->modifyPendingBreakpoints(target->scriptThread);
        target->computeStoppedLine(L);
        lua_break(L);
        // Clear out the interrupt and debugstep callback after we are done.
        lua_callbacks(L)->interrupt = nullptr;
        lua_callbacks(L)->debugstep = nullptr;
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
            target->paused = true;
            target->childRuntime->stopDebug();
            target->stoppedThread = L;
            target->stoppedThreadRef = getRefForThread(L);
            target->stoppedLine = ar->currentline;
            target->stepInfo = std::nullopt;
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
