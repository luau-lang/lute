#include "lute/clivfs.h"

#include "clicommands.h"

#include "Luau/Common.h"

#include <string>

static bool isCliModule(const std::string& path)
{
    CliModuleResult result = getCliModule(path);
    return result.type == CliModuleType::Module;
}

static std::optional<std::string> readCliModule(const std::string& path)
{
    CliModuleResult result = getCliModule(path);
    if (result.type == CliModuleType::Module)
        return std::string(result.contents);

    return std::nullopt;
}

static bool isCliDirectory(const std::string& path)
{
    CliModuleResult result = getCliModule(path);
    return result.type == CliModuleType::Directory;
}

NavigationStatus CliVfs::resetToPath(const std::string& path)
{
    std::string cliPrefix = "@cli/";

    if (path == "@cli")
    {
        modulePath = ModulePath(cliPrefix, cliPrefix.size() - 1, isCliModule, isCliDirectory);
        return NavigationStatus::Success;
    }

    if (path.find_first_of(cliPrefix) != 0)
        return NavigationStatus::NotFound;

    CliModuleResult result = getCliModule(path);
    if (result.type == CliModuleType::NotFound)
        return NavigationStatus::NotFound;

    modulePath = ModulePath(path, cliPrefix.size() - 1, isCliModule, isCliDirectory);
    return NavigationStatus::Success;
}

NavigationStatus CliVfs::toParent()
{
    LUAU_ASSERT(modulePath);
    return modulePath->toParent();
}

NavigationStatus CliVfs::toChild(const std::string& name)
{
    LUAU_ASSERT(modulePath);
    return modulePath->toChild(name);
}

bool CliVfs::isModulePresent() const
{
    return getCliModule(getIdentifier()).type == CliModuleType::Module;
}

std::string CliVfs::getIdentifier() const
{
    LUAU_ASSERT(modulePath);
    ResolvedRealPath result = modulePath->getRealPath();
    LUAU_ASSERT(result.status == NavigationStatus::Success);
    return result.realPath;
}

std::optional<std::string> CliVfs::getContents(const std::string& path) const
{
    return readCliModule(path);
}

bool CliVfs::isConfigPresent() const
{
    // Currently, we do not support .luaurc files in CLI commands.
    return false;
}

std::optional<std::string> CliVfs::getConfig() const
{
    // Currently, we do not support .luaurc files in CLI commands.
    return std::nullopt;
}
