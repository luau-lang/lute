#pragma once

#include "lute/reporter.h"
#include "lute/userlandvfs.h"

#include "Luau/DenseHash.h"
#include "Luau/FileResolver.h"

#include <optional>
#include <string>

namespace Luau
{

// Based on CliFileResolver in Analyze.cpp.
struct LuteTypeCheckModuleResolver : Luau::FileResolver
{
    LuteTypeCheckModuleResolver(LuteReporter& reporter);

    // Enables package-aware require resolution backed by a lockfile-derived
    // UserlandVfs. After this is called, @<package_alias> requires are resolved
    // through the package graph, in addition to the existing built-in aliases.
    void setUserlandVfs(Package::UserlandVfs userlandVfs);

    std::optional<Luau::SourceCode> readSource(const Luau::ModuleName& name) override;

    // We are currently resolving modules and requires only, and will add support for Roblox globals / types in a subsequent PR.
    std::optional<Luau::ModuleInfo> resolveModule(const Luau::ModuleInfo* context, Luau::AstExpr* node, const TypeCheckLimits& limits) override;
    std::string getHumanReadableModuleName(const Luau::ModuleName& name) const override;

    Luau::DenseHashMap<std::string, std::string> sourceCache{""};
    LuteReporter& reporter;
    std::optional<Package::UserlandVfs> userlandVfs;
};

} // namespace Luau
