#pragma once

#include "Luau/LuauConfig.h"

namespace Luau
{

// Based on CliConfigResolver in Analyze.cpp.
struct LuteConfigResolver : Luau::ConfigResolver
{
    Luau::Config defaultConfig;
    mutable std::unordered_map<std::string, Luau::Config> configCache;
    mutable std::vector<std::pair<std::string, std::string>> configErrors;

    LuteConfigResolver(Luau::Mode mode);

    const Luau::Config& getConfig(const Luau::ModuleName& name) const override;

    const Luau::Config& readConfigRec(const std::string& path) const;
};

} // namespace Luau
