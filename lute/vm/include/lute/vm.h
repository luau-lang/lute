#pragma once

#include "lute/library.h"

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library
int luaopen_vm(lua_State* L);
// open the library as a table on top of the stack
int luteopen_vm(lua_State* L);

struct VM : LuteLibrary<VM>
{
    static constexpr const char kName[] = "vm";
    static int lua_spawn(lua_State* L);
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
    static const char* const properties[];
};
