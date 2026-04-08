#pragma once

#include "lute/library.h"

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library
int luaopen_system(lua_State* L);
// open the library as a table on top of the stack
int luteopen_system(lua_State* L);

struct System : LuteLibrary<System>
{
    static constexpr const char kName[] = "system";
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
};
