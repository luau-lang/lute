#include "lute/stdlibvfs.h"

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
    StdLibModuleResult result = getStdLibModule(path);
    return result.type == StdLibModuleType::Directory;
}

NavigationStatus StdLibVfs::resetToPath(const std::string& path)
{
    std::string stdPrefix = "@std/";

    if (path == "@std")
    {
        modulePath = ModulePath(stdPrefix, stdPrefix.size() - 1, isStdLibModule, isStdLibDirectory);
        return NavigationStatus::Success;
    }

    if (path.find_first_of(stdPrefix) != 0)
        return NavigationStatus::NotFound;

    StdLibModuleResult result = getStdLibModule(path);
    if (result.type == StdLibModuleType::NotFound)
        return NavigationStatus::NotFound;

    modulePath = ModulePath(path, stdPrefix.size() - 1, isStdLibModule, isStdLibDirectory);
    return NavigationStatus::Success;
}

NavigationStatus StdLibVfs::toParent()
{
    LUAU_ASSERT(modulePath);
    return modulePath->toParent();
}

NavigationStatus StdLibVfs::toChild(const std::string& name)
{
    LUAU_ASSERT(modulePath);
    return modulePath->toChild(name);
}

bool StdLibVfs::isModulePresent() const
{
    return getStdLibModule(getIdentifier()).type == StdLibModuleType::Module;
}

std::string StdLibVfs::getIdentifier() const
{
    LUAU_ASSERT(modulePath);
    ResolvedRealPath result = modulePath->getRealPath();
    LUAU_ASSERT(result.status == NavigationStatus::Success);
    return result.realPath;
}

std::optional<std::string> StdLibVfs::getContents(const std::string& path) const
{
    return readStdLibModule(path);
}

bool StdLibVfs::isConfigPresent() const
{
    // Currently, we do not support .luaurc files in the standard library.
    return false;
}

std::optional<std::string> StdLibVfs::getConfig() const
{
    // Currently, we do not support .luaurc files in the standard library.
    return std::nullopt;
}
