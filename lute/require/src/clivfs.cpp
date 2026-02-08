#include "lute/clivfs.h"

#include "lute/clibatteries.h"
#include "lute/clicommands.h"
#include "lute/modulepath.h"

#include "Luau/Common.h"

#include <string>

constexpr std::string_view kBatteriesAliasPrefix = "@batteries";
constexpr std::string_view kBatteriesPrefix = "batteries";

constexpr std::string_view kCliAliasPrefix = "@cli";

static bool isBatteryModule(const std::string& path)
{
    BatteryModuleResult result = getBatteryModule(path);
    return result.type == BatteryModuleType::Module;
}

static std::optional<std::string> readBatteryModule(const std::string& path)
{
    BatteryModuleResult result = getBatteryModule(path);
    if (result.type == BatteryModuleType::Module)
        return std::string(result.contents);
    return std::nullopt;
}

static bool isBatteryDirectory(const std::string& path)
{
    if (path == kBatteriesAliasPrefix)
        return true;

    BatteryModuleResult result = getBatteryModule(path);
    return result.type == BatteryModuleType::Directory;
}

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
    if (path == kBatteriesAliasPrefix)
    {
        modulePath = ModulePath::create(std::string(kBatteriesAliasPrefix), "", isBatteryModule, isBatteryDirectory);
        return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
    }
    else if (path == kCliAliasPrefix)
    {
        modulePath = ModulePath::create(std::string(kCliAliasPrefix), "", isCliModule, isCliDirectory);
        return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
    }

    if (path.rfind(kBatteriesAliasPrefix, 0) == 0)
    {
        modulePath = ModulePath::create(
            std::string(kBatteriesAliasPrefix), path.substr(kBatteriesAliasPrefix.size() + 1), isBatteryModule, isBatteryDirectory
        );
        return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
    }
    else if (path.rfind(kCliAliasPrefix, 0) == 0)
    {
        std::string stripped = path.substr(kCliAliasPrefix.size() + 1);
        modulePath = ModulePath::create(std::string(kCliAliasPrefix), stripped, isCliModule, isCliDirectory);
        return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
    }

    return NavigationStatus::NotFound;
}

NavigationStatus CliVfs::toAliasFallback(std::string_view aliasUnprefixed)
{
    if (aliasUnprefixed == kBatteriesPrefix)
        return resetToPath(std::string(kBatteriesAliasPrefix));

    return NavigationStatus::NotFound;
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
    auto id = getIdentifier();
    if (id.rfind(kBatteriesAliasPrefix, 0) == 0)
        return getBatteryModule(id).type == BatteryModuleType::Module;
    return getCliModule(id).type == CliModuleType::Module;
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
    if (path.rfind(kBatteriesAliasPrefix, 0) == 0)
        return readBatteryModule(path);
    return readCliModule(path);
}

ConfigStatus CliVfs::getConfigStatus() const
{
    // Currently, we do not support .luaurc files in CLI commands.
    return ConfigStatus::Absent;
}

std::optional<std::string> CliVfs::getConfig() const
{
    // Currently, we do not support .luaurc files in CLI commands.
    return std::nullopt;
}
