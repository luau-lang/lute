#pragma once

#include "lua.h"

#include <array>
#include <optional>
#include <string>
#include <string_view>

inline constexpr std::array<std::string_view, 3> kNativeSuffixes = {".dylib", ".so", ".dll"};

bool isNativeModule(const std::string& path);
int loadNativeModule(lua_State* L, const std::string& path);
void releaseNativeModules(lua_State* L);
std::optional<std::string> readNativeModuleTypes(const std::string& path);
