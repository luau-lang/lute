#include "lute/clivfs.h"

#include "lute/clicommands.h"
#include "lute/common.h"
#include "lute/modulepath.h"

#include <string>

constexpr std::string_view kCliAliasPrefix = "@cli";
constexpr std::string_view kCliConfig = R"(
{
    "aliases": {
        "lint": "@std/commands/lint/types",
        "transform": "@std/commands/transform/types"
    }
}
)";

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
    if (path == kCliAliasPrefix)
        return true;

    CliModuleResult result = getCliModule(path);
    return result.type == CliModuleType::Directory;
}

NavigationStatus CliVfs::resetToPath(const std::string& path)
{
    if (path.rfind(kCliAliasPrefix, 0) == 0)
    {
        std::string filePath = path == kCliAliasPrefix ? "" : path.substr(kCliAliasPrefix.size() + 1);
        modulePath = ModulePath::create(std::string(kCliAliasPrefix), filePath, isCliModule, isCliDirectory);
        return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
    }

    return NavigationStatus::NotFound;
}

NavigationStatus CliVfs::toParent()
{
    LUTE_ASSERT(modulePath);
    return modulePath->toParent();
}

NavigationStatus CliVfs::toChild(const std::string& name)
{
    LUTE_ASSERT(modulePath);
    return modulePath->toChild(name);
}

bool CliVfs::isModulePresent() const
{
    return getCliModule(getIdentifier()).type == CliModuleType::Module;
}

std::string CliVfs::getIdentifier() const
{
    LUTE_ASSERT(modulePath);
    ResolvedRealPath result = modulePath->getRealPath();
    LUTE_ASSERT(result.status == NavigationStatus::Success);
    return result.realPath;
}

std::optional<std::string> CliVfs::getContents(const std::string& path) const
{
    return readCliModule(path);
}

ConfigStatus CliVfs::getConfigStatus() const
{
    return ConfigStatus::PresentJson;
}

std::optional<std::string_view> CliVfs::getConfig() const
{
    return kCliConfig;
}
