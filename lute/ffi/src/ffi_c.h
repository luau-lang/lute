#pragma once

#include "lua.h"
#include "lualib.h"

namespace ffi
{

int openCInterface(lua_State* L);

} // namespace ffi