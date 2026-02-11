#include "lute/stdlibvfs.h"

#include "lute/common.h"
#include "lute/modulepath.h"
#include "lute/stdlib.h"

#include "Luau/Common.h"

#include <string>

static bool isStdLibModule(const std::string& path)
{
    StdLibModuleResult result = getStdLibModule(path);
    return result.type == StdLibModuleType::Module;
}

static std::optional<std::string> readStdLibModule(const std::string& path)
{
    StdLibModuleResult result = getStdLibModule(path);
    if (result.type == StdLibModuleType::Module)
        return std::string(result.contents);

    return std::nullopt;
}

static bool isStdLibDirectory(const std::string& path)
{
    if (path == "@std")
        return true;
    StdLibModuleResult result = getStdLibModule(path);
    return result.type == StdLibModuleType::Directory;
}

NavigationStatus StdLibVfs::resetToPath(const std::string& path)
{
    if (path == "@std")
    {
        modulePath = ModulePath::create("@std", "", isStdLibModule, isStdLibDirectory);
        return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
    }

    std::string stdPrefix = "@std/";

    if (path.find_first_of(stdPrefix) != 0)
        return NavigationStatus::NotFound;

    modulePath = ModulePath::create("@std", path.substr(stdPrefix.size()), isStdLibModule, isStdLibDirectory);
    return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
}

NavigationStatus StdLibVfs::toParent()
{
    LUTE_ASSERT(modulePath);
    return modulePath->toParent();
}

NavigationStatus StdLibVfs::toChild(const std::string& name)
{
    LUTE_ASSERT(modulePath);
    return modulePath->toChild(name);
}

bool StdLibVfs::isModulePresent() const
{
    return getStdLibModule(getIdentifier()).type == StdLibModuleType::Module;
}

std::string StdLibVfs::getIdentifier() const
{
    LUTE_ASSERT(modulePath);
    ResolvedRealPath result = modulePath->getRealPath();
    LUTE_ASSERT(result.status == NavigationStatus::Success);
    return result.realPath;
}

std::optional<std::string> StdLibVfs::getContents(const std::string& path) const
{
    return readStdLibModule(path);
}

ConfigStatus StdLibVfs::getConfigStatus() const
{
    // Currently, we do not support .luaurc files in the standard library.
    return ConfigStatus::Absent;
}

std::optional<std::string> StdLibVfs::getConfig() const
{
    // Currently, we do not support .luaurc files in the standard library.
    return std::nullopt;
}
