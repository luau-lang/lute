#include "lute/net.h"

#include "lua.h"

int Net::pushLibrary(lua_State* L)
{
    lua_createtable(L, 0, 2);

    NetClient::pushLibrary(L);
    lua_setfield(L, -2, "client");

    NetServer::pushLibrary(L);
    lua_setfield(L, -2, "server");

    lua_setreadonly(L, -1, 1);

    return 1;
}

int luaopen_net(lua_State* L)
{
    return Net::openAsGlobal(L);
}

int luteopen_net(lua_State* L)
{
    return Net::pushLibrary(L);
}
