#include "lute/modulepath.h"

#include "Luau/FileUtils.h"

#include "doctest.h"
#include "luteprojectroot.h"

TEST_CASE("module_path")
{
    for (const std::string& luteProjectRoot : {getLuteProjectRootRelative(), getLuteProjectRootAbsolute()})
    {
        std::string modulePathRoot = joinPaths(luteProjectRoot, "tests/src/modulepathroot");
        std::string file = "module/init.luau";

        std::optional<ModulePath> mp = ModulePath::create(modulePathRoot, file, isFile, isDirectory);
        REQUIRE(mp);

        SUBCASE("parent_to_root")
        {
            CHECK(mp->toParent() == NavigationStatus::Success);
            CHECK(mp->getRealPath().realPath == modulePathRoot);
        }
        SUBCASE("parent_past_root")
        {
            CHECK(mp->toParent() == NavigationStatus::Success);
            CHECK(mp->toParent() == NavigationStatus::NotFound);
        }
        SUBCASE("parent_then_child")
        {
            CHECK(mp->toParent() == NavigationStatus::Success);
            CHECK(mp->toChild("module") == NavigationStatus::Success);
            CHECK(mp->getRealPath().realPath == joinPaths(modulePathRoot, "module/init.luau"));
        }
        SUBCASE("child")
        {
            CHECK(mp->toChild("submodule") == NavigationStatus::Success);
            CHECK(mp->getRealPath().realPath == joinPaths(modulePathRoot, "module/submodule.luau"));
        }
        SUBCASE("child_not_found")
        {
            CHECK(mp->toChild("submodule") == NavigationStatus::Success);
            CHECK(mp->toChild("nonexistant") == NavigationStatus::NotFound);
        }
        SUBCASE("child_then_parent")
        {
            CHECK(mp->toChild("submodule") == NavigationStatus::Success);
            CHECK(mp->toParent() == NavigationStatus::Success);
            CHECK(mp->getRealPath().realPath == joinPaths(modulePathRoot, "module/init.luau"));
        }
    }
}

TEST_CASE("module_path_bare_directory_not_ambiguous")
{
    for (const std::string& luteProjectRoot : {getLuteProjectRootRelative(), getLuteProjectRootAbsolute()})
    {
        std::string modulePathRoot = joinPaths(luteProjectRoot, "tests/src/modulepathroot");
        std::string file = "module/init.luau";

        std::optional<ModulePath> mp = ModulePath::create(modulePathRoot, file, isFile, isDirectory);
        REQUIRE(mp);

        SUBCASE("file_with_sibling_bare_directory_resolves")
        {
            CHECK(mp->toParent() == NavigationStatus::Success);
            CHECK(mp->toChild("baredir") == NavigationStatus::Success);
            CHECK(mp->getRealPath().realPath == joinPaths(modulePathRoot, "baredir.luau"));
            CHECK(mp->getRealPath().type == ResolvedRealPath::PathType::File);
        }

        SUBCASE("bare_directory_child_resolves")
        {
            CHECK(mp->toParent() == NavigationStatus::Success);
            CHECK(mp->toChild("baredir") == NavigationStatus::Success);
            CHECK(mp->toChild("child") == NavigationStatus::Success);
            CHECK(mp->getRealPath().realPath == joinPaths(modulePathRoot, "baredir/child.luau"));
        }

        SUBCASE("file_with_sibling_init_directory_is_ambiguous")
        {
            CHECK(mp->toParent() == NavigationStatus::Success);
            CHECK(mp->toChild("ambiguous") == NavigationStatus::Ambiguous);
        }
    }
}
