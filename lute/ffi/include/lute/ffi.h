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
int new_c_function(lua_State* L);
int load_library(lua_State* L);
int new_c_struct(lua_State* L);
int new_c_box(lua_State* L);
}

int luaopen_cffi(lua_State* L);

} // namespace ffi
