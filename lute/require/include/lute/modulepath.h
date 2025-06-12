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
    // (rootDirectory + '/' + filePath) is the full path to the initial file.
    // rootDirectory serves as the boundary for parenting, preventing toParent()
    // from navigating above it. In the simplest cases, rootDirectory might be
    // "C:" (Windows) or "" (Unix-like systems), but it could be a more specific
    // directory in cases where the ModulePath is intended to power navigation
    // strictly within a subtree of a virtual filesystem.
    static std::optional<ModulePath> create(
        std::string rootDirectory,
        std::string filePath,
        bool (*isAFile)(const std::string&),
        bool (*isADirectory)(const std::string&),
        std::optional<std::string> relativePathToTrack = std::nullopt
    );

    ResolvedRealPath getRealPath() const;
    std::string getPotentialLuaurcPath() const;

    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

private:
    ModulePath(
        std::string realPathPrefix,
        std::string modulePath,
        bool (*isAFile)(const std::string&),
        bool (*isADirectory)(const std::string&),
        std::optional<std::string> relativePathToTrack = std::nullopt
    );

    bool (*isAFile)(const std::string&);
    bool (*isADirectory)(const std::string&);

    std::string realPathPrefix;
    std::string modulePath;
    std::optional<std::string> relativePathToTrack;
};
