#pragma once

#include <string_view>

enum class CliModuleType
{
    Module,
    Directory,
    NotFound,
};

struct CliModuleResult
{
    CliModuleType type;
    std::string_view contents;
};

CliModuleResult getCliModule(std::string_view path);
