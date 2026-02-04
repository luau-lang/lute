#pragma once

#include "lutefixture.h"
#include "lua.h"
#include "Luau/TypeArena.h"

class TypeSerializeFixture : public LuteFixture
{
public:
    TypeSerializeFixture();
    ~TypeSerializeFixture();

    lua_State* L = nullptr;
    Luau::TypeArena arena;
};