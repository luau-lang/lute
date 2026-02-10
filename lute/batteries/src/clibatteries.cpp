#include "lute/clibatteries.h"

// This file provides batteries for the cli commands

#include <string_view>

#include "batteries.h"

BatteryModuleResult getBatteryModule(std::string_view path)
{
    for (const auto& [pathInLib, contents] : lutebatteries)
    {
        if (path != pathInLib)
            continue;

        if (contents == "#directory")
            return {BatteryModuleType::Directory};
        else
            return {BatteryModuleType::Module, contents};
    }

    return {BatteryModuleType::NotFound};
}
