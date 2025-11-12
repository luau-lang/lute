#include "lute/filevfs.h"

#include "lute/modulepath.h"
#include "lute/uvutils.h"

#include "Luau/Common.h"
#include "Luau/Config.h"
#include "Luau/FileUtils.h"
#include "Luau/LuauConfig.h"

#include "uv.h"

#include <array>
#include <string>
#include <string_view>

NavigationStatus FileVfs::resetToStdIn()
{
    std::optional<std::string> cwd = getCurrentWorkingDirectory();
    if (!cwd)
        return NavigationStatus::NotFound;

    size_t firstSlash = cwd->find_first_of("\\/");
    LUAU_ASSERT(firstSlash != std::string::npos);

    modulePath = ModulePath::create(cwd->substr(0, firstSlash), cwd->substr(firstSlash + 1), isFile, isDirectory, "./");
    return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
}

NavigationStatus FileVfs::resetToPath(const std::string& path)
{
    std::string pathToProcess = path;

    // Handle tilde expansion for home directory
    if (!path.empty() && path[0] == '~')
    {
        auto result = uvutils::getStringFromUv(uv_os_homedir);
        if (result.get_if<uvutils::UvError>() != nullptr)
            return NavigationStatus::NotFound;

        std::string* homeDir = result.get_if<std::string>();

        // Replace ~ with home directory
        if (path.size() == 1)
            pathToProcess = *homeDir;
        else if (path[1] == '/' || path[1] == '\\')
            pathToProcess = *homeDir + path.substr(1);
    }

    std::string normalizedPath = normalizePath(pathToProcess);

    if (isAbsolutePath(normalizedPath))
    {
        size_t firstSlash = normalizedPath.find_first_of('/');
        LUAU_ASSERT(firstSlash != std::string::npos);

        modulePath = ModulePath::create(normalizedPath.substr(0, firstSlash), normalizedPath.substr(firstSlash + 1), isFile, isDirectory);
    }
    else
    {
        std::optional<std::string> cwd = getCurrentWorkingDirectory();
        if (!cwd)
            return NavigationStatus::NotFound;

        std::string joinedPath = normalizePath(*cwd + "/" + normalizedPath);

        size_t firstSlash = joinedPath.find_first_of("\\/");
        LUAU_ASSERT(firstSlash != std::string::npos);

        modulePath = ModulePath::create(joinedPath.substr(0, firstSlash), joinedPath.substr(firstSlash + 1), isFile, isDirectory, normalizedPath);
    }

    return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
}

NavigationStatus FileVfs::toParent()
{
    LUAU_ASSERT(modulePath);
    return modulePath->toParent();
}

NavigationStatus FileVfs::toChild(const std::string& name)
{
    LUAU_ASSERT(modulePath);
    return modulePath->toChild(name);
}

bool FileVfs::isModulePresent() const
{
    return isFile(getAbsoluteFilePath());
}

std::string FileVfs::getFilePath() const
{
    LUAU_ASSERT(modulePath);
    ResolvedRealPath result = modulePath->getRealPath();
    LUAU_ASSERT(result.status == NavigationStatus::Success);
    return result.relativePath ? *result.relativePath : result.realPath;
}

std::string FileVfs::getAbsoluteFilePath() const
{
    LUAU_ASSERT(modulePath);
    ResolvedRealPath result = modulePath->getRealPath();
    LUAU_ASSERT(result.status == NavigationStatus::Success);
    return result.realPath;
}

std::optional<std::string> FileVfs::getContents(const std::string& path) const
{
    return readFile(path);
}

ConfigStatus FileVfs::getConfigStatus() const
{
    LUAU_ASSERT(modulePath);

    bool luaurcExists = isFile(modulePath->getPotentialConfigPath(Luau::kConfigName));
    bool luauConfigExists = isFile(modulePath->getPotentialConfigPath(Luau::kLuauConfigName));

    if (luaurcExists && luauConfigExists)
        return ConfigStatus::Ambiguous;
    else if (luauConfigExists)
        return ConfigStatus::PresentLuau;
    else if (luaurcExists)
        return ConfigStatus::PresentJson;

    return ConfigStatus::Absent;
}

std::optional<std::string> FileVfs::getConfig() const
{
    LUAU_ASSERT(modulePath);

    ConfigStatus status = getConfigStatus();
    LUAU_ASSERT(status == ConfigStatus::PresentJson || status == ConfigStatus::PresentLuau);

    if (status == ConfigStatus::PresentJson)
        return readFile(modulePath->getPotentialConfigPath(Luau::kConfigName));
    else if (status == ConfigStatus::PresentLuau)
        return readFile(modulePath->getPotentialConfigPath(Luau::kLuauConfigName));

    LUAU_UNREACHABLE();
}
