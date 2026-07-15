#include "debugger.h"

#include "lute/common.h"

#include "Luau/Compiler.h"
#include "Luau/DenseHash.h"
#include "Luau/StringUtils.h"

#include "lua.h"
#include "lualib.h"

#include <cstddef>
#include <fstream>
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
    childRuntime.reset();
}

Breakpoint Target::setBreakpoint(std::string sourcePath, int line)
{
    std::unique_lock lock(targetMutex);
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
        bool installed = installBreakpoint(childRuntime->GL, it->second);
        Breakpoint bpCopy = it->second;
        lock.unlock();
        if (installed && launchConfig.onBreakpointInstall)
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
            if (installBreakpoint(L, bp) && launchConfig.onBreakpointInstall)
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

bool Target::launch(const std::string& sourcePath, const std::vector<std::string>& args, LaunchConfig config)
{
    std::vector<Breakpoint> installedBps;
    std::vector<Breakpoint> uninstalledBps;
    {
        std::lock_guard lock(targetMutex);
        // launch() cannot be called twice from the same target.
        LUTE_ASSERT(!launched);
        childRuntime = std::make_unique<Runtime>(parentRuntime.reporter);
        setupState(*childRuntime, nullptr);
        launchConfig = config;

        std::ifstream file(sourcePath);
        if (!file.is_open())
        {
            childRuntime.reset();
            return false;
        }
        std::string source((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
        Luau::CompileOptions debugOptions = {};
        debugOptions.optimizationLevel = 1;
        debugOptions.debugLevel = 2;
        std::string bytecode = Luau::compile(source, debugOptions);
        lua_State* thread = lua_newthread(childRuntime->GL);
        luaL_sandboxthread(thread);
        luau_load(thread, sourcePath.c_str(), bytecode.c_str(), bytecode.size(), 0);
        loadedSources[sourcePath] = std::make_shared<Ref>(thread, -1);
        std::tie(installedBps, uninstalledBps) = modifyPendingBreakpoints(thread);
        for (const std::string& arg : args)
            lua_pushstring(thread, arg.c_str());
        childRuntime->runningThreads.push_back({true, getRefForThread(thread), static_cast<int>(args.size())});
        lua_pop(childRuntime->GL, 1);

        scriptThread = thread;
        installBpHitCallback();
        installExitCallback();
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
    return true;
}

void Target::installBpHitCallback()
{
    lua_Callbacks* cb = lua_callbacks(childRuntime->GL);
    cb->userdata = this;
    cb->debugbreak = [](lua_State* L, lua_Debug* ar)
    {
        auto target = static_cast<Target*>(lua_callbacks(L)->userdata);
        // TODO: this pause/resume mechanism assumes single co-routine runtime
        // We land on the same instruction after a continue() after hitting a bp so we basically don't do anything
        std::unique_lock lock(target->targetMutex);
        if (target->continueRequestedBp)
        {
            target->continueRequestedBp = false;
            return;
        }
        lua_Debug info = {};
        lua_getinfo(L, 0, "sl", &info);
        int line = info.currentline;
        if (!info.source)
        {
            target->parentRuntime.reporter.reportError(Luau::format("breakpoint hit at line %d could not find a runtime source", line));
            return;
        }
        std::string source = info.source;
        std::optional<Breakpoint> bp = target->getBreakpointBySourceLineHelper(source, line);
        // Only stop execution on installed breakpoints; otherwise, don't stop.
        if (bp && bp->status == BreakpointStatus::Installed)
        {
            target->bpHit = *bp;
            target->resumeToken = getResumeToken(L);
            target->paused = true;
            lua_break(L);
            auto [installed, uninstalled] = target->modifyPendingBreakpoints(target->scriptThread);
            lock.unlock();
            if (target->launchConfig.onBreakpointHit)
                target->launchConfig.onBreakpointHit(bp.value());
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
                Luau::format("breakpoint hit at line %d in %s could not be found in breakpoint map", line, source.c_str())
            );
        }
    };
}

// TODO: this exit handler assumes single coroutine runtime
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

bool Target::continueProcess()
{

    std::unique_lock lock(targetMutex);
    if (!paused || !resumeToken)
        return false;
    // we are continuing on a breakpoint and so might need to flag continueRequestedBp.
    if (bpHit)
    {
        // we need to check if our breakpoint is still currently installed after
        // onBreakpointHit() callback
        std::optional<Breakpoint> currentBp = getBreakpointByIdHelper(bpHit->id);
        if (currentBp && currentBp->status == BreakpointStatus::Installed)
            continueRequestedBp = true;
        bpHit = std::nullopt;
    }
    resumeToken->complete(
        [](lua_State* L)
        {
            return 0;
        }
    );
    resumeToken = nullptr;
    paused = false;
    return true;
}
} // namespace debug
