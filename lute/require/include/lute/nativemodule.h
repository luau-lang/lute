#pragma once

#include "lua.h"

#include <optional>
#include <string>

bool isNativeLibrary(const std::string& path);

int loadNativeModule(lua_State* L, const std::string& path);

std::optional<std::string> readNativeModuleTypes(const std::string& path);
