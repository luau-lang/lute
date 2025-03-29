#pragma once

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library
int luaopen_process(lua_State* L);
// open the library as a table on top of the stack
int luteopen_process(lua_State* L);

namespace process
{

int create(lua_State* L);

static const luaL_Reg lib[] = {
    {"create", create},
    {nullptr, nullptr}
};

} // namespace process
