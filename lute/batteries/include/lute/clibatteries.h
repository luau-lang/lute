#pragma once

#include <optional>
#include <string>
#include <string_view>

enum class BatteryModuleType
{
    Module,
    Directory,
    NotFound,
};

struct BatteryModuleResult
{
    BatteryModuleType type;
    std::string_view contents;
};

BatteryModuleResult getBatteryModule(std::string_view path);
