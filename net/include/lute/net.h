#pragma once

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library
int luaopen_net(lua_State* L);
// open the library as a table on top of the stack
int luteopen_net(lua_State* L);

namespace net
{

int get(lua_State* L);

int getAsync(lua_State* L);

int serve(lua_State* L);

static const luaL_Reg lib[] = {
    {"get", get},
    {"getAsync", getAsync},
    {"serve", serve},
    {nullptr, nullptr},
};

} // namespace net
