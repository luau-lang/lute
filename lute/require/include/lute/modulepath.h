#pragma once

#include <functional>
#include <optional>
#include <string>

enum class NavigationStatus
{
    Success,
    Ambiguous,
    NotFound
};

enum class ConfigStatus
{
    Absent,
    Ambiguous,
    PresentJson,
    PresentLuau
};

struct ResolvedRealPath
{
    enum class PathType
    {
        File,
        Directory
    };

    NavigationStatus status;
    std::string realPath;
    std::optional<std::string> relativePath;
    PathType type;
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
        std::function<bool(const std::string&)> isAFile,
        std::function<bool(const std::string&)> isADirectory,
        std::optional<std::string> relativePathToTrack = std::nullopt
    );

    ResolvedRealPath getRealPath() const;
    std::string getPotentialConfigPath(const std::string& name) const;

    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

private:
    ModulePath(
        std::string realPathPrefix,
        std::string modulePath,
        std::function<bool(const std::string&)> isAFile,
        std::function<bool(const std::string&)> isADirectory,
        std::optional<std::string> relativePathToTrack = std::nullopt
    );

    std::function<bool(const std::string&)> isAFile;
    std::function<bool(const std::string&)> isADirectory;

    std::string realPathPrefix;
    std::string modulePath;
    std::optional<std::string> relativePathToTrack;
};
