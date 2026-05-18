#include "lute/clibatteries.h"

// This file provides batteries for the cli commands

#include <optional>
#include <string>
#include <string_view>
#include <utility>

#include "batteries.h"

BatteryModuleResult getBatteryModule(std::string_view path)
{
    for (const EmbeddedModule& module : lutebatteries)
    {
        if (path != module.path)
            continue;

        if (module.isDirectory)
            return {BatteryModuleType::Directory};

        std::optional<std::string> contents = decompressEmbeddedModule(module);
        if (contents)
            return {BatteryModuleType::Module, std::move(*contents)};
    }

    return {BatteryModuleType::NotFound};
}
