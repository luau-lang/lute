#include "lute/clicommands.h"

CliModuleResult getCliModule(std::string_view)
{
    return {CliModuleType::NotFound};
}

std::optional<CliCommandResult> getCliCommand(std::string_view)
{
    return std::nullopt;
}
