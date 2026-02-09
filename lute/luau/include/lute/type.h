#pragma once

#include "Luau/TypeFwd.h"

#include "lua.h"

namespace Luau
{

int serializeType(lua_State* L, TypeId ty);
int serializeTypePack(lua_State* L, TypePackId tp);

} // namespace Luau
