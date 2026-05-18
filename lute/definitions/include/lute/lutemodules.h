#pragma once

#include <string>
#include <string_view>

enum class LuteModuleType
{
    Module,
    Directory,
    NotFound,
};

struct LuteModuleResult
{
    LuteModuleType type;
    std::string contents;
};

LuteModuleResult getLuteModule(std::string_view path);
