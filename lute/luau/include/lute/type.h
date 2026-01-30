#pragma once

#include "Luau/TypeFwd.h"

#include "lua.h"

namespace Luau
{

void serializeType(TypeId ty, lua_State* L);
void serializeTypePack(TypePackId tp, lua_State* L);

} // namespace Luau
