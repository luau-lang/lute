#pragma once

#include <functional>
#include <optional>
#include <string>
#include <string_view>

enum class NavigationStatus
{
    Success,
    Ambiguous,
    NotFound
};

bool isBarePath(std::string_view path);

template<typename Vfs>
NavigationStatus walkBarePath(std::string_view path, Vfs& vfs)
{
    NavigationStatus status = NavigationStatus::Success;
    while (!path.empty())
    {
        size_t sep = path.find('/');
        std::string_view component = (sep == std::string_view::npos) ? path : path.substr(0, sep);

        if (component == "..")
            status = vfs.toParent();
        else if (component != ".")
            status = vfs.toChild(std::string(component));

        if (status != NavigationStatus::Success)
            return status;
        path = (sep == std::string_view::npos) ? std::string_view{} : path.substr(sep + 1);
    }
    return status;
}

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
