#pragma once

#include <optional>
#include <string>

enum class NavigationStatus
{
    Success,
    Ambiguous,
    NotFound
};

struct ResolvedRealPath
{
    NavigationStatus status;
    std::string realPath;
    std::optional<std::string> relativePath;
};

class ModulePath
{
public:
    ModulePath(
        std::string filePath,
        size_t endRootDirectory,
        bool (*isAFile)(const std::string&),
        bool (*isADirectory)(const std::string&),
        std::optional<std::string> relativePathToTrack = std::nullopt
    );

    ResolvedRealPath getRealPath() const;
    std::string getPotentialLuaurcPath() const;

    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

private:
    bool (*isAFile)(const std::string&);
    bool (*isADirectory)(const std::string&);

    std::string modulePath;
    std::string realPathPrefix;
    std::optional<std::string> relativePathToTrack;
};
