#pragma once

#include <string>
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
    std::string contents;
};

StdLibModuleResult getStdLibModule(std::string_view path);
