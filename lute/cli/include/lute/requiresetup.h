#pragma once

#include "Luau/DenseHash.h"

#include <functional>
#include <string>

struct lua_State;
struct Runtime;

lua_State* setupCliState(Runtime& runtime, std::function<void(lua_State*)> preSandboxInit = nullptr);
lua_State* setupBundleState(
    Runtime& runtime,
    Luau::DenseHashMap<std::string, std::string> luaurcFiles,
    Luau::DenseHashMap<std::string, std::string> bundleMap
);
