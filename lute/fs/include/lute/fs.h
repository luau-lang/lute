#pragma once

#include "lute/library.h"

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library
LUTE_API int luaopen_fs(lua_State* L);
// open the library as a table on top of the stack
LUTE_API int luteopen_fs(lua_State* L);

struct FS : LuteLibrary<FS>
{
    static constexpr const char kName[] = "fs";
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
    static const char* const properties[];
};
