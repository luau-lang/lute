#include "luteprojectroot.h"

#include "Luau/FileUtils.h"

#include "doctest.h"

std::string getLuteProjectRootAbsolute()
{
    std::optional<std::string> cwd = getCurrentWorkingDirectory();
    REQUIRE(cwd);

    for (char& c : *cwd)
    {
        if (c == '\\')
            c = '/';
    }

    std::string luteDir = *cwd;

    for (int i = 0; i < 20; ++i)
    {
        if (isFile(joinPaths(luteDir, ".LUTE_SENTINEL")))
        {
            return luteDir;
        }

        std::optional<std::string> parentPath = getParentPath(luteDir);
        REQUIRE_MESSAGE(parentPath, "Error getting parent path");
        luteDir = *parentPath;
    }

    REQUIRE_MESSAGE(false, "Error getting Lute project path");
    return "";
}

std::string getLuteProjectRootRelative()
{
    std::string luteDir = "./";

    for (int i = 0; i < 20; ++i)
    {
        if (isFile(joinPaths(luteDir, ".LUTE_SENTINEL")))
        {
            return luteDir;
        }

        luteDir = normalizePath(luteDir + "/..");
    }

    REQUIRE_MESSAGE(false, "Error getting Lute project path");
    return "";
}
