#pragma once

#include "lute/userlandvfs.h"

#include "Luau/DenseHash.h"

#include <functional>
#include <string>

struct lua_State;
struct Runtime;

lua_State* setupRunState(Runtime& runtime, std::function<void(lua_State*)> preSandboxInit = nullptr);

lua_State* setupCliCommandState(Runtime& runtime, std::function<void(lua_State*)> preSandboxInit = nullptr);

// Variant of setupCliCommandState that also wires up package-aware require
// resolution. The CLI command itself can still use @@cli/, @std, @lute, and
// @batteries; user code loaded via this state can additionally resolve
// @<package_alias> requires through the supplied dependency graph.
lua_State* setupPkgCliCommandState(
    Runtime& runtime,
    std::vector<Package::Identifier> directDependencies,
    std::vector<std::pair<Package::Identifier, Package::Info>> allDependencies,
    std::function<void(lua_State*)> preSandboxInit = nullptr
);

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
