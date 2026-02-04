#include "typeserializefixture.h"

#include "lua.h"
#include "lualib.h"

TypeSerializeFixture::TypeSerializeFixture()
{
    L = luaL_newstate();
    luaL_openlibs(L);
}

TypeSerializeFixture::~TypeSerializeFixture()
{
    lua_close(L);
}