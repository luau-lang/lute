#pragma once

#include "lute/library.h"
#include "lute/resolvemodule.h"

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library
int luaopen_luau(lua_State* L);
// open the library as a table on top of the stack
int luteopen_luau(lua_State* L);

struct LuauLib : LuteLibrary<LuauLib>
{
    static constexpr const char kName[] = "luau";
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
    static const char* const properties[];
};
