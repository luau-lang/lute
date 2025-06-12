#include "lute/modulepath.h"

#include "Luau/FileUtils.h"

#include <array>
#include <cassert>
#include <string>
#include <string_view>

const std::array<std::string_view, 2> kSuffixes = {".luau", ".lua"};
const std::array<std::string_view, 2> kInitSuffixes = {"/init.luau", "/init.lua"};

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
    return path;
}

std::optional<ModulePath> ModulePath::create(
    std::string rootDirectory,
    std::string filePath,
    bool (*isAFile)(const std::string&),
    bool (*isADirectory)(const std::string&),
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
    bool (*isAFile)(const std::string&),
    bool (*isADirectory)(const std::string&),
    std::optional<std::string> relativePathToTrack
)
    : isAFile(isAFile)
    , isADirectory(isADirectory)
    , realPathPrefix(std::move(realPathPrefix))
    , modulePath(std::move(modulePath))
    , relativePathToTrack(std::move(relativePathToTrack))
{
}

ResolvedRealPath ModulePath::getRealPath() const
{
    bool found = false;
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
                if (found)
                    return {NavigationStatus::Ambiguous};

                suffix = potentialSuffix;
                found = true;
            }
        }
    }

    if (isADirectory(partialRealPath))
    {
        if (found)
            return {NavigationStatus::Ambiguous};

        for (std::string_view potentialSuffix : kInitSuffixes)
        {
            if (isAFile(partialRealPath + std::string(potentialSuffix)))
            {
                if (found)
                    return {NavigationStatus::Ambiguous};

                suffix = potentialSuffix;
                found = true;
            }
        }

        found = true;
    }

    if (!found)
        return {NavigationStatus::NotFound};

    std::optional<std::string> relativePathWithSuffix;
    if (relativePathToTrack)
        relativePathWithSuffix = *relativePathToTrack + suffix;

    return {NavigationStatus::Success, partialRealPath + suffix, relativePathWithSuffix};
}

std::string ModulePath::getPotentialLuaurcPath() const
{
    ResolvedRealPath result = getRealPath();

    // No navigation has been performed; we should already be in a valid state.
    assert(result.status == NavigationStatus::Success);

    std::string_view directory = result.realPath;

    for (std::string_view suffix : kInitSuffixes)
    {
        if (hasSuffix(directory, suffix))
        {
            directory.remove_suffix(suffix.size());
            return std::string(directory) + "/.luaurc";
        }
    }
    for (std::string_view suffix : kSuffixes)
    {
        if (hasSuffix(directory, suffix))
        {
            directory.remove_suffix(suffix.size());
            return std::string(directory) + "/.luaurc";
        }
    }

    return std::string(directory) + "/.luaurc";
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

    return getRealPath().status;
}

NavigationStatus ModulePath::toChild(const std::string& name)
{
    if (modulePath.empty())
        modulePath = name;
    else
        modulePath += "/" + name;

    if (relativePathToTrack)
        relativePathToTrack = normalizePath(joinPaths(*relativePathToTrack, name));

    return getRealPath().status;
}
