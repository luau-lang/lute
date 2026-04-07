#include "lute/net.h"

#include "lua.h"
#include "lualib.h"

int luaopen_net(lua_State* L)
{
    luteopen_net(L);
    lua_setglobal(L, "net");

    return 1;
}

int luteopen_net(lua_State* L)
{
    lua_createtable(L, 0, 4);

    lua_pushcfunction(L, net::client::request, "request");
    lua_setfield(L, -2, "request");

    lua_pushcfunction(L, net::server::serve, "serve");
    lua_setfield(L, -2, "serve");

    luteopen_net_client(L);
    lua_setfield(L, -2, "client");

    luteopen_net_server(L);
    lua_setfield(L, -2, "server");

    lua_setreadonly(L, -1, 1);

    return 1;
}
