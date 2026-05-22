#pragma once

#include "lua.h"

namespace process
{
int signalFunc(lua_State* L);
} // namespace process

void registerSignalHandle(lua_State* L);
