#include "lute/batteriesvfs.h"

#include "lute/clibatteries.h"
#include "lute/common.h"
#include "lute/modulepath.h"

#include "Luau/Common.h"

#include <string>

constexpr std::string_view kBatteriesAliasPrefix = "@batteries";

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

NavigationStatus BatteriesVfs::resetToPath(const std::string& path)
{
    std::string filePath = path == kBatteriesAliasPrefix ? "" : path.substr(kBatteriesAliasPrefix.size() + 1);

    if (path.rfind(kBatteriesAliasPrefix, 0) != 0)
        return NavigationStatus::NotFound;

    modulePath = ModulePath::create(std::string(kBatteriesAliasPrefix), filePath, isBatteryModule, isBatteryDirectory);
    return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
}

NavigationStatus BatteriesVfs::toParent()
{
    LUTE_ASSERT(modulePath);
    return modulePath->toParent();
}

NavigationStatus BatteriesVfs::toChild(const std::string& name)
{
    LUTE_ASSERT(modulePath);
    return modulePath->toChild(name);
}

bool BatteriesVfs::isModulePresent() const
{
    return getBatteryModule(getIdentifier()).type == BatteryModuleType::Module;
}

std::string BatteriesVfs::getIdentifier() const
{
    LUTE_ASSERT(modulePath);
    ResolvedRealPath result = modulePath->getRealPath();
    LUTE_ASSERT(result.status == NavigationStatus::Success);
    return result.realPath;
}

std::optional<std::string> BatteriesVfs::getContents(const std::string& path) const
{
    return readBatteryModule(path);
}

ConfigStatus BatteriesVfs::getConfigStatus() const
{
    return ConfigStatus::Absent;
}

std::optional<std::string> BatteriesVfs::getConfig() const
{
    return std::nullopt;
}
