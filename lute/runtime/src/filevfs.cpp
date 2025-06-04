#include "lute/filevfs.h"

#include "lute/modulepath.h"

#include "Luau/Common.h"
#include "Luau/FileUtils.h"

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
    modulePath = ModulePath(*cwd + "/stdin", firstSlash, isFile, isDirectory, "./");

    return NavigationStatus::Success;
}

NavigationStatus FileVfs::resetToPath(const std::string& path)
{
    std::string normalizedPath = normalizePath(path);

    if (isAbsolutePath(normalizedPath))
    {
        size_t firstSlash = normalizedPath.find_first_of('/');
        LUAU_ASSERT(firstSlash != std::string::npos);
        modulePath = ModulePath(normalizedPath, firstSlash, isFile, isDirectory);
    }
    else
    {
        std::optional<std::string> cwd = getCurrentWorkingDirectory();
        if (!cwd)
            return NavigationStatus::NotFound;

        std::string joinedPath = normalizePath(*cwd + "/" + normalizedPath);

        size_t firstSlash = joinedPath.find_first_of("\\/");
        LUAU_ASSERT(firstSlash != std::string::npos);
        modulePath = ModulePath(joinedPath, firstSlash, isFile, isDirectory, normalizedPath);
    }

    LUAU_ASSERT(modulePath);
    return modulePath->getRealPath().status;
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

bool FileVfs::isConfigPresent() const
{
    LUAU_ASSERT(modulePath);
    return isFile(modulePath->getPotentialLuaurcPath());
}

std::optional<std::string> FileVfs::getConfig() const
{
    LUAU_ASSERT(modulePath);
    return readFile(modulePath->getPotentialLuaurcPath());
}
