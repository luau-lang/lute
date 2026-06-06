#include "lute/net.h"

#include "lua.h"

#include <iterator>

const luaL_Reg Net::lib[] = {
    {nullptr, nullptr},
};

const char* const Net::properties[] = {"client", "server"};

int Net::pushLibrary(lua_State* L)
{
    lua_createtable(L, 0, std::size(Net::properties));

    NetClient::verifyInterface();
    NetClient::pushLibrary(L);
    lua_setfield(L, -2, "client");

    NetServer::verifyInterface();
    NetServer::pushLibrary(L);
    lua_setfield(L, -2, "server");

    lua_setreadonly(L, -1, 1);

    return 1;
}

LUTE_API int luaopen_net(lua_State* L)
{
    return Net::openAsGlobal(L);
}

LUTE_API int luteopen_net(lua_State* L)
{
    return Net::pushLibrary(L);
}
