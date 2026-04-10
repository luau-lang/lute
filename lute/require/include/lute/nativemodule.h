#pragma once

#include "lua.h"

#include <string>

bool isNativeLibrary(const std::string& path);

int loadNativeModule(lua_State* L, const std::string& path);
