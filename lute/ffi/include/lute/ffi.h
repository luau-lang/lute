#pragma once

#include "lute/library.h"

#include "lua.h"
#include "lualib.h"

#include <string>

// open the library as a standard global luau library
int luaopen_ffi(lua_State* L);
// open the library as a table on top of the stack
int luteopen_ffi(lua_State* L);

// open the ffi.c library as a table on top of the stack
int luteopen_ffi_c(lua_State* L);

struct FFI : LuteLibrary<FFI>
{
    static constexpr const char kName[] = "ffi";
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
    static const char* const properties[];
};

struct FFIC : LuteLibrary<FFIC>
{
    static constexpr const char kName[] = "ffi.c";
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
    static const char* const properties[];
};
