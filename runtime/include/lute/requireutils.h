#pragma once

#include <optional>
#include <string>
#include <string_view>

enum class VFSType
{
    Disk,
    Std,

    // FIXME: this is a temporary workaround until Luau.Require provides an
    // API for registering the @lute/* libraries.
    Lute,
};

struct PathResult
{
    enum class Status
    {
        SUCCESS,
        AMBIGUOUS,
        NOT_FOUND
    };

    Status status;
    std::string absPath;
    std::string relPath;
    std::string suffix;
};

PathResult getStdInResult();
PathResult getAbsolutePathResult(VFSType vfsType, const std::string& path);
PathResult getStdLibModuleResult(VFSType vfsType, const std::string& path);

// If given an absolute path, this will implicitly call getAbsolutePathResult.
// Aliases prevent us from solely operating on relative paths, so we need to
// be able to fall back to operating on absolute paths if needed.
PathResult tryGetRelativePathResult(const std::string& path);

PathResult getParent(VFSType vfsType, const std::string& absPath, const std::string& relPath);
PathResult getChild(VFSType vfsType, const std::string& absPath, const std::string& relPath, const std::string& name);

bool isFilePresent(VFSType vfsType, const std::string& path, const std::string& suffix);
std::optional<std::string> getFileContents(VFSType vfsType, const std::string& path, const std::string& suffix);
