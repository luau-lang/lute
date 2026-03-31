#pragma once

#include "Luau/Config.h"

#include <string>
#include <utility>
#include <vector>

struct lua_State;

Luau::Config resolveConfig(const std::string& filePath, std::vector<std::pair<std::string, std::string>>* configErrors);
int resolveConfig_luau(lua_State* L);
