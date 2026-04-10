#include "lute/modulepath.h"

#include "Luau/FileUtils.h"

#include <array>
#include <cassert>
#include <string>
#include <string_view>

const std::array<std::string_view, 2> kSuffixes = {".luau", ".lua"};
const std::array<std::string_view, 2> kInitSuffixes = {"/init.luau", "/init.lua"};

const std::array<std::string_view, 3> kNativeSuffixes = {".dylib", ".so", ".dll"};

static bool hasSuffix(std::string_view str, std::string_view suffix)
{
    return str.size() >= suffix.size() && str.substr(str.size() - suffix.size()) == suffix;
}

static std::string_view removeExtension(std::string_view path)
{
    for (std::string_view suffix : kInitSuffixes)
    {
        if (hasSuffix(path, suffix))
        {
            path.remove_suffix(suffix.size());
            return path;
        }
    }
    for (std::string_view suffix : kSuffixes)
    {
        if (hasSuffix(path, suffix))
        {
            path.remove_suffix(suffix.size());
            return path;
        }
    }
    for (std::string_view suffix : kNativeSuffixes)
    {
        if (hasSuffix(path, suffix))
        {
            path.remove_suffix(suffix.size());
            return path;
        }
    }
    return path;
}

std::optional<ModulePath> ModulePath::create(
    std::string rootDirectory,
    std::string filePath,
    std::function<bool(const std::string&)> isAFile,
    std::function<bool(const std::string&)> isADirectory,
    std::optional<std::string> relativePathToTrack
)
{
    for (char& c : rootDirectory)
    {
        if (c == '\\')
            c = '/';
    }

    for (char& c : filePath)
    {
        if (c == '\\')
            c = '/';
    }

    std::string_view modulePath = removeExtension(filePath);

    if (relativePathToTrack)
        relativePathToTrack = removeExtension(*relativePathToTrack);

    ModulePath mp = ModulePath(std::move(rootDirectory), std::string{modulePath}, isAFile, isADirectory, std::move(relativePathToTrack));

    // The ModulePath must start in a valid state.
    if (mp.getRealPath().status == NavigationStatus::NotFound)
        return std::nullopt;

    return mp;
}

ModulePath::ModulePath(
    std::string realPathPrefix,
    std::string modulePath,
    std::function<bool(const std::string&)> isAFile,
    std::function<bool(const std::string&)> isADirectory,
    std::optional<std::string> relativePathToTrack
)
    : isAFile(std::move(isAFile))
    , isADirectory(std::move(isADirectory))
    , realPathPrefix(std::move(realPathPrefix))
    , modulePath(std::move(modulePath))
    , relativePathToTrack(std::move(relativePathToTrack))
{
}

ResolvedRealPath ModulePath::getRealPath() const
{
    std::optional<ResolvedRealPath::PathType> resolvedType;
    std::string suffix;

    std::string lastComponent;
    if (size_t lastSlash = modulePath.find_last_of('/'); lastSlash != std::string::npos)
        lastComponent = modulePath.substr(lastSlash + 1);

    std::string partialRealPath = realPathPrefix;
    if (!modulePath.empty())
    {
        partialRealPath += '/';
        partialRealPath += modulePath;
    }

    if (lastComponent != "init")
    {
        for (std::string_view potentialSuffix : kSuffixes)
        {
            if (isAFile(partialRealPath + std::string(potentialSuffix)))
            {
                if (resolvedType)
                    return {NavigationStatus::Ambiguous};

                resolvedType = ResolvedRealPath::PathType::File;
                suffix = potentialSuffix;
            }
        }

        // Check for native shared libraries (.dylib, .so, .dll)
        if (!resolvedType)
        {
            for (std::string_view potentialSuffix : kNativeSuffixes)
            {
                if (isAFile(partialRealPath + std::string(potentialSuffix)))
                {
                    if (resolvedType)
                        return {NavigationStatus::Ambiguous};

                    resolvedType = ResolvedRealPath::PathType::File;
                    suffix = potentialSuffix;
                }
            }
        }
    }

    if (isADirectory(partialRealPath))
    {
        if (resolvedType)
            return {NavigationStatus::Ambiguous};

        for (std::string_view potentialSuffix : kInitSuffixes)
        {
            if (isAFile(partialRealPath + std::string(potentialSuffix)))
            {
                if (resolvedType)
                    return {NavigationStatus::Ambiguous};

                resolvedType = ResolvedRealPath::PathType::File;
                suffix = potentialSuffix;
            }
        }

        if (!resolvedType)
            resolvedType = ResolvedRealPath::PathType::Directory;
    }

    if (!resolvedType)
        return {NavigationStatus::NotFound};

    std::optional<std::string> relativePathWithSuffix;
    if (relativePathToTrack)
        relativePathWithSuffix = *relativePathToTrack + suffix;

    return {NavigationStatus::Success, partialRealPath + suffix, relativePathWithSuffix, *resolvedType};
}

std::string ModulePath::getPotentialConfigPath(const std::string& name) const
{
    ResolvedRealPath result = getRealPath();

    // No navigation has been performed; we should already be in a valid state.
    assert(result.status != NavigationStatus::NotFound);

    std::string_view directory = result.realPath;

    for (std::string_view suffix : kInitSuffixes)
    {
        if (hasSuffix(directory, suffix))
        {
            directory.remove_suffix(suffix.size());
            return std::string(directory) + "/" + name;
        }
    }
    for (std::string_view suffix : kSuffixes)
    {
        if (hasSuffix(directory, suffix))
        {
            directory.remove_suffix(suffix.size());
            return std::string(directory) + "/" + name;
        }
    }

    return std::string(directory) + "/" + name;
}

NavigationStatus ModulePath::toParent()
{
    if (modulePath.empty())
        return NavigationStatus::NotFound;

    if (size_t lastSlash = modulePath.find_last_of('/'); lastSlash == std::string::npos)
        modulePath.clear();
    else
        modulePath = modulePath.substr(0, lastSlash);

    if (relativePathToTrack)
        relativePathToTrack = normalizePath(joinPaths(*relativePathToTrack, ".."));

    // There is no ambiguity when navigating up in a tree.
    NavigationStatus status = getRealPath().status;
    return status == NavigationStatus::Ambiguous ? NavigationStatus::Success : status;
}

NavigationStatus ModulePath::toChild(const std::string& name)
{
    if (name == ".config")
        return NavigationStatus::NotFound;

    if (modulePath.empty())
        modulePath = name;
    else
        modulePath += "/" + name;

    if (relativePathToTrack)
        relativePathToTrack = normalizePath(joinPaths(*relativePathToTrack, name));

    return getRealPath().status;
}
