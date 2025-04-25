#include "lute/requireutils.h"

#include "Luau/FileUtils.h"
#include "lute/stdlib.h"

#include <algorithm>
#include <optional>
#include <string>
#include <string_view>

static bool isStdLibModule(const std::string& path)
{
    StdLibModuleResult result = getStdLibModule(path);
    return result.type == StdLibModuleType::Module;
}

static std::optional<std::string> readStdLibModule(const std::string& path)
{
    StdLibModuleResult result = getStdLibModule(path);
    if (result.type == StdLibModuleType::Module)
        return std::string(result.contents);

    return std::nullopt;
}

static bool isStdLibDirectory(const std::string& path)
{
    StdLibModuleResult result = getStdLibModule(path);
    return result.type == StdLibModuleType::Directory;
}

static std::pair<PathResult::Status, std::string> getSuffixWithAmbiguityCheck(VFSType vfsType, const std::string& path)
{
    bool found = false;
    std::string suffix;

    bool (*isAFile)(const std::string&) = vfsType == VFSType::Disk ? isFile : isStdLibModule;
    bool (*isADirectory)(const std::string&) = vfsType == VFSType::Disk ? isDirectory : isStdLibDirectory;

    for (const char* potentialSuffix : {".luau", ".lua"})
    {
        if (isAFile(path + potentialSuffix))
        {
            if (found)
                return {PathResult::Status::AMBIGUOUS, ""};

            suffix = potentialSuffix;
            found = true;
        }
    }
    if (isADirectory(path))
    {
        if (found)
            return {PathResult::Status::AMBIGUOUS, ""};

        for (const char* potentialSuffix : {"/init.luau", "/init.lua"})
        {
            if (isFile(path + potentialSuffix))
            {
                if (found)
                    return {PathResult::Status::AMBIGUOUS, ""};

                suffix = potentialSuffix;
                found = true;
            }
        }

        found = true;
    }

    if (!found)
        return {PathResult::Status::NOT_FOUND, ""};

    return {PathResult::Status::SUCCESS, suffix};
}

static PathResult addSuffix(VFSType vfsType, PathResult partialResult)
{
    // FIXME: this is a temporary workaround until Luau.Require provides an
    // API for registering the @lute/* libraries.
    if (vfsType == VFSType::Lute)
        return partialResult;

    if (partialResult.status != PathResult::Status::SUCCESS)
        return partialResult;

    auto [status, suffix] = getSuffixWithAmbiguityCheck(vfsType, partialResult.absPath);
    if (status != PathResult::Status::SUCCESS)
        return PathResult{status};

    partialResult.suffix = std::move(suffix);
    return partialResult;
}

PathResult getStdInResult()
{
    std::optional<std::string> cwd = getCurrentWorkingDirectory();
    if (!cwd)
        return PathResult{PathResult::Status::NOT_FOUND};

    std::replace(cwd->begin(), cwd->end(), '\\', '/');

    return PathResult{PathResult::Status::SUCCESS, *cwd + "/stdin", "./stdin", ""};
}

PathResult getAbsolutePathResult(VFSType vfsType, const std::string& path)
{
    return addSuffix(vfsType, PathResult{PathResult::Status::SUCCESS, path});
}

PathResult tryGetRelativePathResult(const std::string& path)
{
    if (isAbsolutePath(path))
        return getAbsolutePathResult(VFSType::Disk, path);

    std::optional<std::string> cwd = getCurrentWorkingDirectory();
    if (!cwd)
        return PathResult{PathResult::Status::NOT_FOUND};

    std::optional<std::string> resolvedAbsPath = resolvePath(path, *cwd + "/stdin");
    if (!resolvedAbsPath)
        return PathResult{PathResult::Status::NOT_FOUND};

    return addSuffix(VFSType::Disk, PathResult{PathResult::Status::SUCCESS, std::move(*resolvedAbsPath), path});
}

PathResult getParent(VFSType vfsType, const std::string& absPath, const std::string& relPath)
{
    std::optional<std::string> parent = getParentPath(absPath);
    if (!parent)
        return PathResult{PathResult::Status::NOT_FOUND};

    return addSuffix(vfsType, PathResult{PathResult::Status::SUCCESS, *parent, normalizePath(relPath + "/..")});
}

PathResult getChild(VFSType vfsType, const std::string& absPath, const std::string& relPath, const std::string& name)
{
    return addSuffix(vfsType, PathResult{PathResult::Status::SUCCESS, joinPaths(absPath, name), joinPaths(relPath, name)});
}

bool isFilePresent(VFSType vfsType, const std::string& path, const std::string& suffix)
{
    if (vfsType == VFSType::Std)
        return isStdLibModule(path + suffix);

    return isFile(path + suffix);
}

std::optional<std::string> getFileContents(VFSType vfsType, const std::string& path, const std::string& suffix)
{
    if (vfsType == VFSType::Std)
        return readStdLibModule(path + suffix);

    return readFile(path + suffix);
}
