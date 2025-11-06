#include "lute/configresolver.h"

#include "Luau/ParseResult.h"
#include "Luau/FileUtils.h"
#include "Luau/LuauConfig.h"

namespace Luau
{

LuteConfigResolver::LuteConfigResolver(Luau::Mode mode)
{
    defaultConfig.mode = mode;
}

const Luau::Config& LuteConfigResolver::getConfig(const Luau::ModuleName& name) const
{
    std::optional<std::string> path = getParentPath(name);
    if (!path)
        return defaultConfig;

    return readConfigRec(*path);
}

const Luau::Config& LuteConfigResolver::readConfigRec(const std::string& path) const
{
    auto it = configCache.find(path);
    if (it != configCache.end())
        return it->second;

    std::optional<std::string> parent = getParentPath(path);
    Luau::Config result = parent ? readConfigRec(*parent) : defaultConfig;

    std::optional<std::string> configPath = joinPaths(path, Luau::kConfigName);
    if (!isFile(*configPath))
        configPath = std::nullopt;

    std::optional<std::string> luauConfigPath = joinPaths(path, Luau::kLuauConfigName);
    if (!isFile(*luauConfigPath))
        luauConfigPath = std::nullopt;

    if (configPath && luauConfigPath)
    {
        std::string ambiguousError = Luau::format("Both %s and %s files exist", Luau::kConfigName, Luau::kLuauConfigName);
        configErrors.emplace_back(*configPath, std::move(ambiguousError));
    }
    else if (configPath)
    {
        if (std::optional<std::string> contents = readFile(*configPath))
        {
            Luau::ConfigOptions::AliasOptions aliasOpts;
            aliasOpts.configLocation = *configPath;
            aliasOpts.overwriteAliases = true;

            Luau::ConfigOptions opts;
            opts.aliasOptions = std::move(aliasOpts);

            std::optional<std::string> error = Luau::parseConfig(*contents, result, opts);
            if (error)
                configErrors.emplace_back(*configPath, *error);
        }
    }
    else if (luauConfigPath)
    {
        if (std::optional<std::string> contents = readFile(*luauConfigPath))
        {
            Luau::ConfigOptions::AliasOptions aliasOpts;
            aliasOpts.configLocation = *configPath;
            aliasOpts.overwriteAliases = true;

            std::optional<std::string> error = Luau::extractLuauConfig(*contents, result, aliasOpts, Luau::InterruptCallbacks{});
            if (error)
                configErrors.emplace_back(*luauConfigPath, *error);
        }
    }

    return configCache[path] = result;
}

} // namespace Luau