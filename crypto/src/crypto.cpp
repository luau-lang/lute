#include "lute/crypto.h"
#include "lua.h"

namespace crypto
{
    int lua_digest(lua_State* L)
    {

    }
} // namespace crypto

int luaopen_crypto(lua_State* L)
{
    luteopen_system(L);
    lua_setglobal(L, "system");

    return 1;
}

int luteopen_crypto(lua_State* L)
{
    lua_createtable(L, 0, std::size(crypto::lib) + std::size(crypto::properties));

    for (auto& [name, func] : crypto::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    return 1;
}
