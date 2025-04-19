#pragma once

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library
int luaopen_system(lua_State* L);
// open the library as a table on top of the stack
int luteopen_system(lua_State* L);

namespace system_lib
{

static const luaL_Reg lib[] = {
    {nullptr, nullptr}
};

} // namespace system
