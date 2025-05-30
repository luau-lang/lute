#include "doctest.h"

#include "lute/modulepath.h"

#include "Luau/FileUtils.h"
#include <iostream>

static std::string getLuteProjectRoot()
{
    std::optional<std::string> cwd = getCurrentWorkingDirectory();
    REQUIRE(cwd);

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

TEST_CASE("module_path")
{
    std::string luteProjectRoot = getLuteProjectRoot();

    std::string modulePathRoot = luteProjectRoot + "/tests/src/modulepathroot/";
    std::string file = modulePathRoot + "module/init.luau";

    ModulePath mp = ModulePath(file, modulePathRoot.size() - 1, isFile, isDirectory);

    SUBCASE("parent_to_root")
    {
        CHECK(mp.toParent() == NavigationStatus::Success);
        CHECK(mp.getRealPath().realPath == modulePathRoot);
    }
    SUBCASE("parent_past_root")
    {
        CHECK(mp.toParent() == NavigationStatus::Success);
        CHECK(mp.toParent() == NavigationStatus::NotFound);
    }
    SUBCASE("parent_then_child")
    {
        CHECK(mp.toParent() == NavigationStatus::Success);
        CHECK(mp.toChild("module") == NavigationStatus::Success);
        CHECK(mp.getRealPath().realPath == modulePathRoot + "module/init.luau");
    }
    SUBCASE("child")
    {
        CHECK(mp.toChild("submodule") == NavigationStatus::Success);
        CHECK(mp.getRealPath().realPath == modulePathRoot + "module/submodule.luau");
    }
    SUBCASE("child_not_found")
    {
        CHECK(mp.toChild("submodule") == NavigationStatus::Success);
        CHECK(mp.toChild("nonexistant") == NavigationStatus::NotFound);
    }
    SUBCASE("child_then_parent")
    {
        CHECK(mp.toChild("submodule") == NavigationStatus::Success);
        CHECK(mp.toParent() == NavigationStatus::Success);
        CHECK(mp.getRealPath().realPath == modulePathRoot + "module/init.luau");
    }
}
