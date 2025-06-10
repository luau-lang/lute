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
    bool removedSuffix = false;
    for (std::string_view suffix : kInitSuffixes)
    {
        if (!removedSuffix && hasSuffix(path, suffix))
        {
            path.remove_suffix(suffix.size());
            removedSuffix = true;
        }
    }
    for (std::string_view suffix : kSuffixes)
    {
        if (!removedSuffix && hasSuffix(path, suffix))
        {
            path.remove_suffix(suffix.size());
            removedSuffix = true;
        }
    }
    return path;
}

ModulePath::ModulePath(
    std::string filePath,
    size_t endRootDirectory,
    bool (*isAFile)(const std::string&),
    bool (*isADirectory)(const std::string&),
    std::optional<std::string> relativePathToTrack
)
    : isAFile(isAFile)
    , isADirectory(isADirectory)
    , relativePathToTrack(std::move(relativePathToTrack))
{
    for (char& c : filePath)
    {
        if (c == '\\')
            c = '/';
    }

    std::string_view pathView = removeExtension(filePath);

    assert(endRootDirectory < pathView.size());
    if (endRootDirectory == pathView.size() - 1)
    {
        realPathPrefix = pathView;
        return;
    }

    realPathPrefix = pathView.substr(0, endRootDirectory + 1);
    modulePath = pathView.substr(endRootDirectory + 1);

    if (this->relativePathToTrack)
        this->relativePathToTrack = removeExtension(*this->relativePathToTrack);
}

ResolvedRealPath ModulePath::getRealPath() const
{
    bool found = false;
    std::string suffix;

    std::string lastComponent;
    if (size_t lastSlash = modulePath.find_last_of('/'); lastSlash != std::string::npos)
        lastComponent = modulePath.substr(lastSlash + 1);

    std::string partialRealPath = realPathPrefix + modulePath;

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
