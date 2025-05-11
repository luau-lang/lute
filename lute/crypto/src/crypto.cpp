#include "lute/crypto.h"
#include "lua.h"

#include "openssl/digest.h"

#include <string>
#include <vector>

namespace crypto
{

    struct HashFunction
    {
        std::string name;
        const env_md_st* md;
    };

    static const int kHashFunctionTag = 81;

    static const HashFunction hashFunctions[] = {
        {"md5", EVP_md5()},
        {"sha1", EVP_sha1()},
        {"sha256", EVP_sha256()},
        {"sha512", EVP_sha512()},
        {"blake2b256", EVP_blake2b256()},
    };

    int makeHashFunctionMap(lua_State* L)
    {
        lua_createtable(L, 0, std::size(hashFunctions));

        for (auto& [name, md] : hashFunctions)
        {
            lua_pushlightuserdatatagged(L, (void*) md, kHashFunctionTag);
            lua_setfield(L, -2, name.c_str());
        }

        return 1;
    }

    const env_md_st* getHashFunction(lua_State* L, int idx)
    {
        if (auto typ = static_cast<const env_md_st*>(lua_tolightuserdatatagged(L, idx, kHashFunctionTag)))
            return typ;

        luaL_typeerrorL(L, idx, "hash function");
    }

    int lua_digest(lua_State* L)
    {
        int argumentCount = lua_gettop(L);
        if (argumentCount != 2)
            luaL_error(L, "%s: expected 2 arguments, but got %d", kDigestName, argumentCount);

        const env_md_st* hashFunction = getHashFunction(L, 1);

        if (!lua_isstring(L, 2) && !lua_isbuffer(L, 2))
            luaL_typeerrorL(L, 2, "string or buffer");

        if (lua_isstring(L, 2))
        {
            size_t length = 0;
            const char* data = lua_tolstring(L, 2, &length);

            void* buffer = lua_newbuffer(L, EVP_MD_size(hashFunction));
            if (EVP_Digest(data, length, (uint8_t*) buffer, nullptr, hashFunction, nullptr) == 0)
                luaL_error(L, "%s: failed to compute hash", kDigestName);
        }
        else if (lua_isbuffer(L, 2))
        {
            size_t length = 0;
            void* data = lua_tobuffer(L, 2, &length);

            void* buffer = lua_newbuffer(L, EVP_MD_size(hashFunction));
            if (EVP_Digest(data, length, (uint8_t*) buffer, nullptr, hashFunction, nullptr) == 0)
                luaL_error(L, "%s: failed to compute hash", kDigestName);
        }

        return 1;
    }

} // namespace crypto

int luaopen_crypto(lua_State* L)
{
    luteopen_crypto(L);
    lua_setglobal(L, "crypto");

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

    crypto::makeHashFunctionMap(L);
    lua_setfield(L, -2, crypto::kHashProperty);

    lua_setreadonly(L, -1, 1);

    return 1;
}
