#pragma once

#include <string_view>

enum class StdLibModuleType
{
    Module,
    Directory,
    NotFound,
};

struct StdLibModuleResult
{
    StdLibModuleType type;
    std::string_view contents;
};

StdLibModuleResult getStdLibModule(std::string_view path);
