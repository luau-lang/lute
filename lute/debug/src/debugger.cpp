#include "debugger.h"

#include "Luau/Compiler.h"

#include "lua.h"
#include "lualib.h"

#include <fstream>
#include <optional>
#include <string>

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
{
}

Breakpoint Target::addBreakpoint(std::string sourcePath, int line)
{
    int id = currentBreakpointId;
    currentBreakpointId++;
    Breakpoint bp(id, sourcePath, line, BreakpointStatus::Pending);
    installBreakpoint(runtime.GL, bp);
    switch (bp.status)
    {
    case BreakpointStatus::Pending:
        pendingBreakpoints.push_back(bp);
        break;
    case BreakpointStatus::Installed:
        installedBreakpoints.push_back(bp);
        break;
    case BreakpointStatus::Invalid:
        invalidBreakpoints.push_back(bp);
        break;
    }
    return bp;
}

std::vector<Breakpoint> Target::getBreakpoints() const
{
    std::vector<Breakpoint> all;
    all.insert(all.end(), installedBreakpoints.begin(), installedBreakpoints.end());
    all.insert(all.end(), pendingBreakpoints.begin(), pendingBreakpoints.end());
    all.insert(all.end(), invalidBreakpoints.begin(), invalidBreakpoints.end());
    return all;
}

std::optional<Breakpoint> Target::getBreakpointById(int breakpointId) const
{
    for (const Breakpoint& bp : installedBreakpoints)
        if (bp.id == breakpointId)
            return bp;
    for (const Breakpoint& bp : pendingBreakpoints)
        if (bp.id == breakpointId)
            return bp;
    return std::nullopt;
}

bool Target::installBreakpoint(lua_State* L, Breakpoint& bp)
{
    auto it = loadedSources.find(bp.sourcePath);
    if (it == loadedSources.end())
        return false;
    it->second->push(L);
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
    for (auto it = pendingBreakpoints.begin(); it != pendingBreakpoints.end();)
    {
        installBreakpoint(L, *it);
        if (it->status == BreakpointStatus::Installed)
        {
            installedBreakpoints.push_back(*it);
            it = pendingBreakpoints.erase(it);
        }
        else
        {
            ++it;
        }
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
