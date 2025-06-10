#pragma once

#include <optional>
#include <string>
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

struct CliCommandResult
{
    std::string_view contents;
    std::string path;
};

std::optional<CliCommandResult> getCliCommand(std::string_view command);
