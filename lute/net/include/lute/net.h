#pragma once

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library
int luaopen_net(lua_State* L);
// open the library as a table on top of the stack
int luteopen_net(lua_State* L);

int luteopen_net_client(lua_State* L);
int luteopen_net_server(lua_State* L);

namespace net::client
{

int request(lua_State* L);

static const luaL_Reg lib[] = {
    {"request", request},
    {nullptr, nullptr},
};

} // namespace net::client

namespace net::server
{

int serve(lua_State* L);

static const luaL_Reg lib[] = {
    {"serve", serve},
    {nullptr, nullptr},
};

} // namespace net::server
