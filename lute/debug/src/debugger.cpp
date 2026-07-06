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

Target::Target(Runtime& parentRuntime, std::string sourcePath)
    : parentRuntime(parentRuntime)
    , sourcePath(sourcePath)
    , loadedSources("")
{
}

Breakpoint Target::addBreakpoint(std::string sourcePath, int line)
{
    int id = currentBreakpointId;
    currentBreakpointId++;
    std::unique_lock lock(breakpointsMutex);
    auto [it, _] = breakpoints.insert_or_assign(id, Breakpoint(id, sourcePath, line, BreakpointStatus::PendingInstall));
    if (childRuntime)
        childRuntime->schedule(
            [this, id]() mutable
            {
                std::unique_lock lock(breakpointsMutex);
                auto it = breakpoints.find(id);
                // check breakpoint has not been erased when this scheduled install has been fired
                if (it != breakpoints.end())
                {
                    bool installed = installBreakpoint(childRuntime->GL, it->second);
                    if (installed && onBreakpointInstall)
                        onBreakpointInstall(it->second);
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
        if (childRuntime)
        {
            bp.status = BreakpointStatus::PendingUninstall;
            childRuntime->schedule(
                [this, bp]() mutable
                {
                    std::unique_lock lock(breakpointsMutex);
                    auto it = breakpoints.find(bp.id);
                    if (it == breakpoints.end())
                    {
                        parentRuntime.reporter.reportError(
                            Luau::format(
                                "breakpoint %d installed at line %d in %s is missing in breakpoint map", bp.id, bp.line, bp.sourcePath.c_str()
                            )
                        );
                        return;
                    }
                    breakpoints.erase(it);
                    auto chunkRef = loadedSources.find(bp.sourcePath);
                    if (!chunkRef)
                    {
                        parentRuntime.reporter.reportError(
                            Luau::format("breakpoint %d installed at line %d in %s is missing a loaded source", bp.id, bp.line, bp.sourcePath.c_str())
                        );
                        return;
                    }
                    (*chunkRef)->push(childRuntime->GL);
                    int removed_line = lua_breakpoint(childRuntime->GL, -1, bp.line, 0);
                    lua_pop(childRuntime->GL, 1);
                    if (removed_line == -1)
                    {
                        parentRuntime.reporter.reportError(
                            Luau::format("breakpoint %d installed at line %d in %s could not be removed", bp.id, bp.line, bp.sourcePath.c_str())
                        );
                        return;
                    }
                    if (onBreakpointUninstall)
                        onBreakpointUninstall(bp);
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
            if (installed && onBreakpointInstall)
                onBreakpointInstall(bp);
        }
    }
}

std::shared_ptr<Process> Target::launch(
    const std::vector<std::string>& args,
    std::function<void(const Breakpoint& bp)> onBreakpointInstall,
    std::function<void(const Breakpoint& bp)> onBreakpointUninstall,
    std::function<void(Process& process, const Breakpoint& bp)> onBreakpointHit
)
{
    // launch() cannot be called twice from the same target.
    if (childRuntime != nullptr)
        return nullptr;
    childRuntime = std::make_shared<Runtime>(parentRuntime.reporter);
    setupState(*childRuntime, nullptr);

    this->onBreakpointInstall = onBreakpointInstall;
    this->onBreakpointUninstall = onBreakpointUninstall;

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

    auto process = std::make_shared<Process>(*childRuntime, *this, onBreakpointHit);
    // All VM setup happens synchronously before runContinuously starts the background thread.
    // The no-op schedule wakes the event loop so it picks up the queued thread.
    childRuntime->schedule([]() {});
    childRuntime->runContinuously();
    return process;
}

Process::Process(Runtime& runtime, Target& parentTarget, std::function<void(Process& process, const Breakpoint& bp)> onBreakpointHit)
    : runtime(runtime)
    , parentTarget(parentTarget)
    , onBreakpointHit(onBreakpointHit)
{
    installBpHitCallback();
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
        int line = ar->currentline;
        lua_Debug info = {};
        lua_getinfo(L, 0, "s", &info);

        Process* process = static_cast<Process*>(lua_callbacks(L)->userdata);
        process->resumeToken = getResumeToken(L);
        std::string source = info.source;
        std::optional<Breakpoint> bp = process->parentTarget.getBreakpointBySourceLine(source, line);
        if (bp)
        {
            // notify caller that we stopped
            if (process->onBreakpointHit)
            {
                process->onBreakpointHit(*process, bp.value());
            }
        }
        else
        {
            // TODO: some error report
        }
    };
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
