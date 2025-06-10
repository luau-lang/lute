#include "lute/crypto.h"
#include "lua.h"

#include "lualib.h"
#include "openssl/digest.h"
#include "sodium/crypto_pwhash.h"

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

    struct BinaryData
    {
        const void* data;
        size_t length;
    };

    BinaryData extractData(lua_State* L, int idx)
    {
        if (!lua_isstring(L, idx) && !lua_isbuffer(L, idx))
            luaL_typeerrorL(L, idx, "string or buffer");

        if (lua_isstring(L, idx))
        {
            size_t length = 0;
            const char* data = lua_tolstring(L, idx, &length);

            return BinaryData{data, length};
        }


        if (lua_isbuffer(L, idx))
        {
            size_t length = 0;
            void* data = lua_tobuffer(L, idx, &length);

            return BinaryData{data, length};
        }

        luaL_error(L, "failed to extract binary data from stack: %d", idx);
    }

    int lua_digest(lua_State* L)
    {
        int argumentCount = lua_gettop(L);
        if (argumentCount != 2)
            luaL_error(L, "%s: expected 2 arguments, but got %d", kDigestName, argumentCount);

        const env_md_st* hashFunction = getHashFunction(L, 1);
        BinaryData message = extractData(L, 2);

        void* buffer = lua_newbuffer(L, EVP_MD_size(hashFunction));
        if (EVP_Digest(message.data, message.length, (uint8_t*) buffer, nullptr, hashFunction, nullptr) == 0)
            luaL_error(L, "%s: failed to compute hash", kDigestName);

        return 1;
    }

    // hash(password: string): buffer
    int lua_pwhash(lua_State* L)
    {
        int argumentCount = lua_gettop(L);
        if (argumentCount != 1)
            luaL_error(L, "%s: expected 1 arguments, but got %d", kPasswordHashName, argumentCount);

        size_t length = 0;
        const char* password = luaL_checklstring(L, 1, &length);

        void* buffer = lua_newbuffer(L, crypto_pwhash_STRBYTES);
        if (crypto_pwhash_str((char*) buffer, password, length,
                              crypto_pwhash_OPSLIMIT_SENSITIVE, crypto_pwhash_MEMLIMIT_SENSITIVE)) {
            luaL_error(L, "%s: hit memory limit for password hashing", kPasswordHashName);
        }

        return 1;
    }

    // verify(hash: buffer, password: string)
    int lua_pwhash_verify(lua_State* L)
    {
        int argumentCount = lua_gettop(L);
        if (argumentCount != 2)
            luaL_error(L, "%s: expected 2 arguments, but got %d", kPasswordHashName, argumentCount);

        size_t hashLength = crypto_pwhash_STRBYTES;
        void* hashedPassword = luaL_checkbuffer(L, 1, &hashLength);

        size_t length = 0;
        const char* password = luaL_checklstring(L, 2, &length);

        lua_pushboolean(L, crypto_pwhash_str_verify((const char*) hashedPassword, password, length) == 0);

        return 1;
    }

    int makePasswordHashLibrary(lua_State* L)
    {
        lua_createtable(L, 0, 2);

        // hash
        lua_pushcfunction(L, lua_pwhash, kPasswordHashName);
        lua_setfield(L, -2, kPasswordHashName);

        // verify
        lua_pushcfunction(L, lua_pwhash_verify, kVerifyPasswordHashName);
        lua_setfield(L, -2, kVerifyPasswordHashName);

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

    crypto::makePasswordHashLibrary(L);
    lua_setfield(L, -2, crypto::kPasswordProperty);

    lua_setreadonly(L, -1, 1);

    return 1;
}
