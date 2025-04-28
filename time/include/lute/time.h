#pragma once

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library
int luaopen_time(lua_State* L);
// open the library as a table on top of the stack
int luteopen_time(lua_State* L);

namespace libtime
{
int lua_now(lua_State* L);

static const luaL_Reg lib[] = {
    {"now", lua_now},

    {nullptr, nullptr},
};

} // namespace libtime
