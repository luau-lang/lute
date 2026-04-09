#pragma once

#include "lute/userlandvfs.h"

#include "Luau/DenseHash.h"

#include <functional>
#include <string>

struct lua_State;
struct Runtime;

lua_State* setupRunState(Runtime& runtime, std::function<void(lua_State*)> preSandboxInit = nullptr);

lua_State* setupCliCommandState(Runtime& runtime, std::function<void(lua_State*)> preSandboxInit = nullptr);

lua_State* setupPkgRunState(
    Runtime& runtime,
    std::vector<Package::Identifier> directDependencies,
    std::vector<std::pair<Package::Identifier, Package::Info>> allDependencies
);

lua_State* setupBundleState(
    Runtime& runtime,
    Luau::DenseHashMap<std::string, std::string> luauConfigFiles,
    Luau::DenseHashMap<std::string, std::string> bundleMap
);
