#include "lute/keyring.h"

#include "keyring_impl.h"

#include "lua.h"
#include "lualib.h"

#include <iterator>

namespace
{

int lua_set(lua_State* L)
{
    size_t serviceLen = 0, accountLen = 0, passLen = 0;
    const char* service = luaL_checklstring(L, 1, &serviceLen);
    const char* account = luaL_checklstring(L, 2, &accountLen);
    const char* password = luaL_checklstring(L, 3, &passLen);

    if (auto error = keyring::setPassword({service, serviceLen}, {account, accountLen}, {password, passLen}))
        luaL_errorL(L, "%s", error->c_str());

    return 0;
}

int lua_get(lua_State* L)
{
    size_t serviceLen = 0, accountLen = 0;
    const char* service = luaL_checklstring(L, 1, &serviceLen);
    const char* account = luaL_checklstring(L, 2, &accountLen);

    keyring::LookupResult result = keyring::getPassword({service, serviceLen}, {account, accountLen});
    if (result.error)
        luaL_errorL(L, "%s", result.error->c_str());

    if (!result.password)
    {
        lua_pushnil(L);
        return 1;
    }

    lua_pushlstring(L, result.password->data(), result.password->size());
    return 1;
}

int lua_delete(lua_State* L)
{
    size_t serviceLen = 0, accountLen = 0;
    const char* service = luaL_checklstring(L, 1, &serviceLen);
    const char* account = luaL_checklstring(L, 2, &accountLen);

    if (auto error = keyring::deletePassword({service, serviceLen}, {account, accountLen}))
        luaL_errorL(L, "%s", error->c_str());

    return 0;
}

int lua_isSupported(lua_State* L)
{
    lua_pushboolean(L, keyring::isSupported());
    return 1;
}

} // namespace

const char* const Keyring::properties[] = {nullptr};

const luaL_Reg Keyring::lib[] = {
    {"set", lua_set},
    {"get", lua_get},
    {"delete", lua_delete},
    {"isSupported", lua_isSupported},
    {nullptr, nullptr},
};

int Keyring::pushLibrary(lua_State* L)
{
    lua_createtable(L, 0, std::size(Keyring::lib));

    for (auto& [name, func] : Keyring::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);
    return 1;
}

LUTE_API int luaopen_keyring(lua_State* L)
{
    return Keyring::openAsGlobal(L);
}

LUTE_API int luteopen_keyring(lua_State* L)
{
    return Keyring::pushLibrary(L);
}
