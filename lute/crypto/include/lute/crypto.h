#pragma once

#include "lua.h"
#include "lualib.h"

#include <string>

// open the library as a standard global luau library
int luaopen_crypto(lua_State* L);
// open the library as a table on top of the stack
int luteopen_crypto(lua_State* L);

namespace crypto
{

static const char kHashProperty[] = "hash";
static const char kPasswordProperty[] = "password";

static const char kDigestName[] = "digest";
int lua_digest(lua_State* L);

static const char kPasswordHashName[] = "hash";
int lua_pwhash(lua_State* L);

static const char kVerifyPasswordHashName[] = "verify";
int lua_pwhash_verify(lua_State* L);

static const luaL_Reg lib[] = {
    {kDigestName, lua_digest},
    {nullptr, nullptr}
};

static const std::string properties[] = {
    kHashProperty,
    kPasswordProperty,
};

} // namespace crypto
