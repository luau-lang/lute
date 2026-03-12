#pragma once

#include "Luau/FileResolver.h"

namespace Luau
{

// Based on CliFileResolver in Analyze.cpp.
struct LuteTypeCheckModuleResolver : Luau::FileResolver
{
    LuteTypeCheckModuleResolver() = default;

    std::optional<Luau::SourceCode> readSource(const Luau::ModuleName& name) override;

    // We are currently resolving modules and requires only, and will add support for Roblox globals / types in a subsequent PR.
    std::optional<Luau::ModuleInfo> resolveModule(const Luau::ModuleInfo* context, Luau::AstExpr* node, const TypeCheckLimits& limits) override;
};

} // namespace Luau
