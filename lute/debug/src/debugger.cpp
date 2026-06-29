#include "debugger.h"

#include "Luau/Compiler.h"
#include "Luau/DenseHash.h"

#include "lua.h"
#include "lualib.h"

#include <fstream>
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

Target::Target(Runtime& runtime, std::string sourcePath)
    : runtime(runtime)
    , sourcePath(sourcePath)
    , loadedSources("")
{
}

Breakpoint Target::addBreakpoint(std::string sourcePath, int line)
{
    int id = currentBreakpointId;
    currentBreakpointId++;
    Breakpoint bp(id, sourcePath, line, BreakpointStatus::Pending);
    installBreakpoint(runtime.GL, bp);
    breakpoints.insert_or_assign(id, bp);
    return bp;
}

bool Target::removeBreakpoint(int bpId)
{
    auto it = breakpoints.find(bpId);
    if (it == breakpoints.end())
        return false;
    Breakpoint& bp = it->second;
    if (bp.status == BreakpointStatus::Installed)
    {
        auto chunkRef = loadedSources.find(bp.sourcePath);
        if (chunkRef)
        {
            (*chunkRef)->push(runtime.GL);
            int removed_line = lua_breakpoint(runtime.GL, -1, bp.line, 0);
            lua_pop(runtime.GL, 1);
            if (removed_line == -1)
                runtime.reporter.reportError("installed breakpoint is invalid in source");
        }
        else
        {
            runtime.reporter.reportError("installed breakpoint has no loaded source");
        }
    }
    breakpoints.erase(it);
    return true;
}

std::vector<Breakpoint> Target::getBreakpoints() const
{
    std::vector<Breakpoint> all;
    all.reserve(breakpoints.size());
    for (auto& [_, bp] : breakpoints)
        all.push_back(bp);
    return all;
}

std::vector<Breakpoint> Target::getBreakpointsByStatus(BreakpointStatus status) const
{
    std::vector<Breakpoint> statusBps;
    for (auto& [_, bp] : breakpoints)
        if (bp.status == status)
            statusBps.push_back(bp);
    return statusBps;
}

std::optional<Breakpoint> Target::getBreakpointById(int breakpointId) const
{
    auto it = breakpoints.find(breakpointId);
    if (it != breakpoints.end())
        return it->second;
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
    for (auto& [_, bp] : breakpoints)
    {
        if (bp.status == BreakpointStatus::Pending)
            installBreakpoint(L, bp);
    }
}

bool Target::launch(const std::vector<std::string>& args)
{
    std::ifstream file(sourcePath);
    if (!file.is_open())
        return false;
    std::string source((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    Luau::CompileOptions debugOptions = {};
    debugOptions.optimizationLevel = 1;
    debugOptions.debugLevel = 2;
    std::string bytecode = Luau::compile(source, debugOptions);
    lua_State* thread = lua_newthread(runtime.GL);
    luaL_sandboxthread(thread);
    luau_load(thread, sourcePath.c_str(), bytecode.c_str(), bytecode.size(), 0);
    loadedSources[sourcePath] = std::make_shared<Ref>(thread, -1);
    installPendingBreakpoints(thread);
    for (const std::string& arg : args)
        lua_pushstring(thread, arg.c_str());
    runtime.runningThreads.push_back({true, getRefForThread(thread), static_cast<int>(args.size())});
    lua_pop(runtime.GL, 1);
    return true;
}
} // namespace debug
