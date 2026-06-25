#include "debugger.h"

#include "lute/clireporter.h"

#include "Luau/Compiler.h"

#include "lua.h"
#include "lualib.h"

#include <algorithm>
#include <fstream>
#include <optional>
#include <string>

namespace debug
{
Breakpoint::Breakpoint(int id, std::string sourcePath, int line, bool installed)
    : id(id)
    , sourcePath(sourcePath)
    , line(line)
    , installed(installed)
{
}

Target::Target(std::string executablePath, Runtime& runtime)
    : executablePath(executablePath)
    , runtime(runtime)
    , launched(false)
{
}

Breakpoint Target::addBreakpoint(std::string sourcePath, int line)
{
    int id = currentBreakpointId;
    currentBreakpointId++;
    Breakpoint bp(id, sourcePath, line, false);
    if (!installBreakpoint(bp, runtime.GL))
    {
        pendingBreakpoints.push_back(bp);
    }
    return bp;
}

std::optional<Breakpoint> Target::getBreakpointById(int breakpointId)
{
    for (const Breakpoint& bp : installedBreakpoints)
        if (bp.id == breakpointId)
            return bp;
    for (const Breakpoint& bp : pendingBreakpoints)
        if (bp.id == breakpointId)
            return bp;
    return std::nullopt;
}

bool Target::installBreakpoint(Breakpoint& bp, lua_State* L)
{
    if (loadedSources.find(bp.sourcePath) == loadedSources.end())
    {
        return false;
    }
    loadedSources[bp.sourcePath]->push(L);
    int installedLine = lua_breakpoint(L, -1, bp.line, 1);
    lua_pop(L, 1);
    if (installedLine == -1)
    {
        return false;
    }
    auto it = std::find(pendingBreakpoints.begin(), pendingBreakpoints.end(), bp);
    if (it != pendingBreakpoints.end())
    {
        pendingBreakpoints.erase(it);
    }
    bp.installed = true;
    bp.line = installedLine;
    installedBreakpoints.push_back(bp);
    return true;
}

void Target::installPendingBreakpoints(lua_State* L)
{
    // copy because we make modifications on pendingBreakpoints
    std::vector<Breakpoint> pendingCopy = pendingBreakpoints;
    for (Breakpoint& bp : pendingCopy)
    {
        installBreakpoint(bp, L);
    }
}

bool Target::launch(std::vector<std::string> args)
{
    std::ifstream file(executablePath);
    if (!file.is_open())
    {
        return false;
    }
    std::string source((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    Luau::CompileOptions debugOptions = {};
    debugOptions.optimizationLevel = 1;
    debugOptions.debugLevel = 2;
    std::string bytecode = Luau::compile(source, debugOptions);
    lua_State* thread = lua_newthread(runtime.GL);
    luaL_sandboxthread(thread);
    luau_load(thread, executablePath.c_str(), bytecode.c_str(), bytecode.size(), 0);
    loadedSources[executablePath] = std::make_shared<Ref>(thread, -1);
    installPendingBreakpoints(thread);
    for (std::string& arg : args)
    {
        lua_pushstring(thread, arg.c_str());
    }
    runtime.runningThreads.push_back({true, getRefForThread(thread), static_cast<int>(args.size())});
    lua_pop(runtime.GL, 1);
    return true;
}
} // namespace debug