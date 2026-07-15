#pragma once

#include "lute/debuginternals.h"
#include "lute/library.h"

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library. note:
// this has a special name bc otherwise, it conflicts with a preexisting Lua library
LUTE_API int luaopen_debug_lute(lua_State* L);
// open the library as a table on top of the stack
LUTE_API int luteopen_debug(lua_State* L);

struct Debug : LuteLibrary<Debug>
{
    static constexpr const char kName[] = "debug";
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
    static const char* const properties[];
};
