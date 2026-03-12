#pragma once

#include <optional>
#include <string>

struct lua_State;

std::optional<std::string> resolveModule(std::string requirePath, std::string requirerChunkname, std::string* error);
int resolveModule_luau(lua_State* L);
