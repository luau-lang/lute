#include "lute/tcmoduleresolver.h"

#include "lute/resolvemodule.h"

#include "Luau/Ast.h"
#include "Luau/FileUtils.h"

namespace Luau
{

std::optional<Luau::SourceCode> LuteTypeCheckModuleResolver::readSource(const Luau::ModuleName& name)
{
    if (std::optional<std::string> source = readFile(name))
        return Luau::SourceCode{*source, Luau::SourceCode::Module};
    return std::nullopt;
}

// We are currently resolving modules and requires only, and will add support for Roblox globals / types in a subsequent PR.
std::optional<Luau::ModuleInfo> LuteTypeCheckModuleResolver::resolveModule(const Luau::ModuleInfo* context, Luau::AstExpr* node, const TypeCheckLimits& limits)
{
    if (auto expr = node->as<Luau::AstExprConstantString>())
    {
        std::string requirePath(expr->value.data, expr->value.size);

        std::string error;
        std::string requirerChunkname = "@" + context->name;
        std::optional<std::string> absolutePath = ::resolveModule(requirePath, std::move(requirerChunkname), &error);
        if (!absolutePath)
        {
            printf("Failed to resolve require: %s\n", error.c_str());
            return std::nullopt;
        }

        return Luau::ModuleInfo{*absolutePath};
    }

    return std::nullopt;
}

} // namespace Luau
