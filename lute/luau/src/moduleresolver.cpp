#include "lute/moduleresolver.h"

#include "Luau/Ast.h"
#include "Luau/FileUtils.h"

#include "lute/resolverequire.h"

namespace Luau
{

LuteModuleResolver::LuteModuleResolver() = default;

std::optional<Luau::SourceCode> LuteModuleResolver::readSource(const Luau::ModuleName& name)
{
    Luau::SourceCode::Type sourceType;
    std::optional<std::string> source = std::nullopt;

    source = readFile(name);
    sourceType = Luau::SourceCode::Module;

    if (!source)
        return std::nullopt;

    return Luau::SourceCode{*source, sourceType};
}

// We are currently resolving modules and requires only, and will add support for Roblox globals / types in a subsequent PR.
std::optional<Luau::ModuleInfo> LuteModuleResolver::resolveModule(const Luau::ModuleInfo* context, Luau::AstExpr* node)
{
    if (auto expr = node->as<Luau::AstExprConstantString>())
    {
        std::string requirePath(expr->value.data, expr->value.size);

        std::string error;
        std::string requirerChunkname = "@" + context->name;
        std::optional<std::string> absolutePath = resolveRequire(requirePath, std::move(requirerChunkname), &error);
        if (!absolutePath)
        {
            printf("Failed to resolve require: %s\n", error.c_str());
            return std::nullopt;
        }

        return {{*absolutePath}};
    }

    return std::nullopt;
}

} // namespace Luau