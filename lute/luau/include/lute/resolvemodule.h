#pragma once

#include <optional>
#include <string>

struct lua_State;

namespace Package
{
class UserlandVfs;
}

struct ResolvedModule
{
    std::string path;
    std::string source;
};

// Plain (non-package-aware) resolution. Handles @std/@lute/@batteries (typecheck
// variant only) and disk paths.
std::optional<std::string> resolveModule(std::string requirePath, std::string requirerChunkname, std::string* error);
std::optional<ResolvedModule> resolveForTypeCheck(std::string requirePath, std::string requirerChunkname, std::string* error);

// Package-aware resolution. The provided userlandVfs is mutated during navigation
// (its dependency map is shared/immutable, but its current-position state is reset
// on each call). Handles @std/@lute/@batteries (typecheck variant only), disk paths,
// and @<package_alias> requires sourced from the lockfile.
std::optional<std::string> resolvePackageModule(
    std::string requirePath,
    std::string requirerChunkname,
    Package::UserlandVfs& userlandVfs,
    std::string* error
);
std::optional<ResolvedModule> resolveForPackageTypeCheck(
    std::string requirePath,
    std::string requirerChunkname,
    Package::UserlandVfs& userlandVfs,
    std::string* error
);

int resolveModule_luau(lua_State* L);
