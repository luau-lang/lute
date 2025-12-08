#pragma once

#include "lua.h"
#include "lualib.h"

#include <string>

// open the library as a standard global luau library
int luaopen_ffi(lua_State* L);
// open the library as a table on top of the stack
int luteopen_ffi(lua_State* L);

namespace ffi
{

namespace cffi
{
int newCFunction(lua_State* L);
int loadLibrary(lua_State* L);
int newCStruct(lua_State* L);
int newCConstant(lua_State* L);
}

int luaopen_cffi(lua_State* L);

} // namespace ffi
