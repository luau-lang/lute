#pragma once

#include "lute/library.h"

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library. note:
// this has a special name bc otherwise, it conflicts with a preexisting Lua library
LUTE_API int luaopen_debugger(lua_State* L);
// open the library as a table on top of the stack
LUTE_API int luteopen_debugger(lua_State* L);

struct Debugger : LuteLibrary<Debugger>
{
    static constexpr const char kName[] = "debugger";
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
    static const char* const properties[];
};
