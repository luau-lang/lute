#include "debugger.h"

#include "Luau/Compiler.h"
#include "Luau/DenseHash.h"
#include "Luau/StringUtils.h"

#include "lua.h"
#include "lualib.h"

#include <fstream>
#include <mutex>
#include <optional>
#include <string>
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

Breakpoint Target::setBreakpoint(std::string sourcePath, int line)
{
    std::optional<Breakpoint> preexistingBp = getBreakpointBySourceLine(sourcePath, line);
    if (preexistingBp)
        return *preexistingBp;
    int id = currentBreakpointId;
    currentBreakpointId++;
    std::unique_lock lock(breakpointsMutex);
    auto [it, _] = breakpoints.insert_or_assign(id, Breakpoint(id, sourcePath, line, BreakpointStatus::PendingInstall));
    // We schedule breakpoint installs to happen async
    if (childRuntime)
        childRuntime->schedule(
            [this, id]()
            {
                std::unique_lock lock(breakpointsMutex);
                auto it = breakpoints.find(id);
                // check breakpoint has not been erased when this scheduled install has been fired
                if (it != breakpoints.end())
                {
                    bool installed = installBreakpoint(childRuntime->GL, it->second);
                    lock.unlock();
                    if (installed && launchConfig.onBreakpointInstall)
                        launchConfig.onBreakpointInstall(it->second);
                }
            }
        );
    return it->second;
}

bool Target::removeBreakpoint(int bpId)
{
    std::unique_lock lock(breakpointsMutex);
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
            bp.status = BreakpointStatus::PendingUninstall;
            childRuntime->schedule(
                [this, bp]()
                {
                    std::unique_lock lock(breakpointsMutex);
                    auto it = breakpoints.find(bp.id);
                    if (it == breakpoints.end())
                    {
                        parentRuntime.reporter.reportError(
                            Luau::format(
                                "breakpoint %d installed at line %d in %s that is queued for uninstall is missing in breakpoint map",
                                bp.id,
                                bp.line,
                                bp.sourcePath.c_str()
                            )
                        );
                        return;
                    }
                    breakpoints.erase(it);
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
                        return;
                    }
                    (*chunkRef)->push(childRuntime->GL);
                    int removed_line = lua_breakpoint(childRuntime->GL, -1, bp.line, 0);
                    lua_pop(childRuntime->GL, 1);
                    if (removed_line == -1)
                    {
                        parentRuntime.reporter.reportError(
                            Luau::format(
                                "breakpoint %d installed at line %d in %s that is queued for uninstall could not be removed",
                                bp.id,
                                bp.line,
                                bp.sourcePath.c_str()
                            )
                        );
                        return;
                    }
                    lock.unlock();
                    if (launchConfig.onBreakpointUninstall)
                        launchConfig.onBreakpointUninstall(bp);
                }
            );
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
    std::unique_lock lock(breakpointsMutex);
    std::vector<Breakpoint> all;
    all.reserve(breakpoints.size());
    for (auto& [_, bp] : breakpoints)
        all.push_back(bp);
    return all;
}

std::vector<Breakpoint> Target::getBreakpointsByStatus(BreakpointStatus status) const
{
    std::unique_lock lock(breakpointsMutex);
    std::vector<Breakpoint> statusBps;
    statusBps.reserve(breakpoints.size());
    for (auto& [_, bp] : breakpoints)
        if (bp.status == status)
            statusBps.push_back(bp);
    return statusBps;
}

std::optional<Breakpoint> Target::getBreakpointById(int breakpointId) const
{
    std::unique_lock lock(breakpointsMutex);
    auto it = breakpoints.find(breakpointId);
    if (it != breakpoints.end())
        return it->second;
    return std::nullopt;
}

std::optional<Breakpoint> Target::getBreakpointBySourceLine(std::string source, int line) const
{
    std::unique_lock lock(breakpointsMutex);
    for (const auto& [_, bp] : breakpoints)
    {
        if (bp.sourcePath == source && bp.line == line)
            return bp;
    }
    return std::nullopt;
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

void Target::installPendingBreakpoints(lua_State* L)
{
    std::unique_lock lock(breakpointsMutex);
    for (auto& [_, bp] : breakpoints)
    {
        if (bp.status == BreakpointStatus::PendingInstall)
        {
            bool installed = installBreakpoint(L, bp);
            if (installed && launchConfig.onBreakpointInstall)
            {
                lock.unlock();
                launchConfig.onBreakpointInstall(bp);
                lock.lock();
            }
        }
    }
}

std::shared_ptr<Process> Target::launch(const std::string sourcePath, const std::vector<std::string>& args, LaunchConfig config)
{
    // launch() cannot be called twice from the same target.
    if (activeProcess != nullptr)
        return nullptr;
    childRuntime = std::make_shared<Runtime>(parentRuntime.reporter);
    setupState(*childRuntime, nullptr);
    launchConfig = config;

    std::ifstream file(sourcePath);
    if (!file.is_open())
        return nullptr;
    std::string source((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    Luau::CompileOptions debugOptions = {};
    debugOptions.optimizationLevel = 1;
    debugOptions.debugLevel = 2;
    std::string bytecode = Luau::compile(source, debugOptions);
    lua_State* thread = lua_newthread(childRuntime->GL);
    luaL_sandboxthread(thread);
    luau_load(thread, sourcePath.c_str(), bytecode.c_str(), bytecode.size(), 0);
    loadedSources[sourcePath] = std::make_shared<Ref>(thread, -1);
    installPendingBreakpoints(thread);
    for (const std::string& arg : args)
        lua_pushstring(thread, arg.c_str());
    childRuntime->runningThreads.push_back({true, getRefForThread(thread), static_cast<int>(args.size())});
    lua_pop(childRuntime->GL, 1);

    std::shared_ptr<Process> process = std::make_shared<Process>(thread, *this, config);
    activeProcess = process;
    // All VM setup happens synchronously before runContinuously starts the background thread.
    // The no-op schedule wakes the event loop so it picks up the queued thread.
    childRuntime->schedule([]() {});
    childRuntime->runContinuously();
    return process;
}

Process::Process(lua_State* thread, Target& parentTarget, LaunchConfig config)
    : thread(thread)
    , runtime(*getRuntime(thread))
    , parentTarget(parentTarget)
    , config(std::move(config))
{
    installBpHitCallback();
    installExitCallback();
}

Target& Process::getTarget()
{
    return parentTarget;
}

void Process::installBpHitCallback()
{
    lua_Callbacks* cb = lua_callbacks(runtime.GL);
    cb->userdata = this;
    cb->debugbreak = [](lua_State* L, lua_Debug* ar)
    {
        Process* process = static_cast<Process*>(lua_callbacks(L)->userdata);
        // TODO: this pause/resume mechanism assumes single co-routine runtime
        process->resumeToken = getResumeToken(L);

        lua_Debug info = {};
        lua_getinfo(L, 0, "sl", &info);
        int line = info.currentline;
        if (!info.source)
        {
            process->runtime.reporter.reportError(Luau::format("breakpoint hit at line %d could not be find a runtime source", line));
            return;
        }
        std::string source = info.source;
        std::optional<Breakpoint> bp = process->parentTarget.getBreakpointBySourceLine(source, line);
        if (bp && bp->status == BreakpointStatus::Installed)
        {
            if (process->config.onBreakpointHit)
                process->config.onBreakpointHit(*process, bp.value());
        }
        else
        {
            // it is normal to hit breakpoints that are pending uninstall but not normal
            // to hit any other type of breakpoint
            if (!bp || bp->status != BreakpointStatus::PendingUninstall)
                process->runtime.reporter.reportError(
                    Luau::format("breakpoint hit at line %d in %s could not be found in breakpoint map", line, source.c_str())
                );
            // this prevents us from hanging forever
            process->continueProcess();
        }
    };
}

// TODO: this exit handler assumes single coroutine runtime
void Process::installExitCallback()
{
    ThreadCompletionHandler completion;
    completion.onFinish = [this](lua_State* L, int status)
    {
        if (config.onExit)
            config.onExit(status == LUA_OK);
    };
    runtime.addThreadCompletionHandler(thread, std::move(completion));
}

bool Process::continueProcess()
{
    if (!resumeToken)
        return false;
    resumeToken->complete(
        [](lua_State* L)
        {
            return 0;
        }
    );
    resumeToken = nullptr;
    return true;
}
} // namespace debug
