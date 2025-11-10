#include "lute/climain.h"

#include "Luau/FileUtils.h"

#include "lua.h"

#include "cliruntimefixture.h"
#include "doctest.h"
#include "luteprojectroot.h"

TEST_CASE_FIXTURE(CliRuntimeFixture, "require_exists")
{
    lua_getglobal(L, "require");
    CHECK(!lua_isnil(L, -1));
}

TEST_CASE("require_modules")
{
    auto doPassingSubcase = [](std::vector<char*> argv, std::string requirePath, std::vector<std::string> expectedResults)
    {
        std::string pass = "pass";
        argv.push_back(pass.data());
        argv.push_back(requirePath.data());
        for (std::string& result : expectedResults)
        {
            argv.push_back(result.data());
        }
        CHECK_EQ(cliMain(argv.size(), argv.data()), 0);
    };

    auto doFailingSubcase = [](std::vector<char*> argv, std::string requirePath, std::vector<std::string> expectedResults)
    {
        std::string fail = "fail";
        argv.push_back(fail.data());
        argv.push_back(requirePath.data());
        for (std::string& result : expectedResults)
        {
            argv.push_back(result.data());
        }
        CHECK_EQ(cliMain(argv.size(), argv.data()), 0);
    };

    char executablePlaceholder[] = "lute";

    for (const std::string& luteProjectRoot : {getLuteProjectRootRelative(), getLuteProjectRootAbsolute()})
    {
        std::string requirer = joinPaths(luteProjectRoot, "tests/src/require/requirer.luau");
        std::vector<char*> argv = {executablePlaceholder, requirer.data()};

        SUBCASE("dependency")
        {
            doPassingSubcase(argv, "./without_config/dependency", {"result from dependency"});
        }

        SUBCASE("lua_dependency")
        {
            doPassingSubcase(argv, "./without_config/lua_dependency", {"result from lua_dependency"});
        }

        SUBCASE("module")
        {
            doPassingSubcase(argv, {"./without_config/module"}, {"result from dependency", "required into module"});
        }

        SUBCASE("init_luau")
        {
            doPassingSubcase(argv, {"./without_config/luau"}, {"result from init.luau"});
        }

        SUBCASE("init_lua")
        {
            doPassingSubcase(argv, {"./without_config/lua"}, {"result from init.lua"});
        }

        SUBCASE("nested_inits")
        {
            doPassingSubcase(argv, {"./without_config/nested_inits_requirer"}, {"result from nested_inits/init", "required into module"});
        }

        SUBCASE("nested_module")
        {
            doPassingSubcase(argv, {"./without_config/nested_module_requirer"}, {"result from submodule", "required into module"});
        }

        SUBCASE("with_directory_ambiguity")
        {
            doFailingSubcase(
                argv,
                {"./without_config/ambiguous_directory_requirer"},
                {R"(error requiring module "./ambiguous/directory/dependency": could not resolve child component "dependency" (ambiguous))"}
            );
        }

        SUBCASE("with_file_ambiguity")
        {
            doFailingSubcase(
                argv,
                {"./without_config/ambiguous_file_requirer"},
                {R"(error requiring module "./ambiguous/file/dependency": could not resolve child component "dependency" (ambiguous))"}
            );
        }

        SUBCASE("with_module_alias")
        {
            doPassingSubcase(argv, {"./config_tests/with_config/src/alias_requirer"}, {"result from dependency"});
            doPassingSubcase(argv, {"./config_tests/with_config_luau/src/alias_requirer"}, {"result from dependency"});
        }

        SUBCASE("with_directory_alias")
        {
            doPassingSubcase(argv, {"./config_tests/with_config/src/directory_alias_requirer"}, {"result from subdirectory_dependency"});
            doPassingSubcase(argv, {"./config_tests/with_config_luau/src/directory_alias_requirer"}, {"result from subdirectory_dependency"});
        }

        SUBCASE("with_parent_configuration_alias")
        {
            doPassingSubcase(argv, {"./config_tests/with_config/src/parent_alias_requirer"}, {"result from other_dependency"});
            doPassingSubcase(argv, {"./config_tests/with_config_luau/src/parent_alias_requirer"}, {"result from other_dependency"});
        }

        SUBCASE("init_does_not_read_sibling_luaurc")
        {
            doPassingSubcase(argv, {"./config_tests/with_config/src/submodule"}, {"result from dependency"});
            doPassingSubcase(argv, {"./config_tests/with_config_luau/src/submodule"}, {"result from dependency"});
        }

        SUBCASE("config_ambiguity")
        {
            doFailingSubcase(
                argv,
                {"./config_tests/config_ambiguity/requirer"},
                {R"(error requiring module "@dep": could not resolve alias "dep" (ambiguous configuration file))"}
            );
        }

        SUBCASE("config_cannot_be_required")
        {
            doFailingSubcase(
                argv,
                {"./config_tests/config_cannot_be_required/requirer"},
                {R"(error requiring module "./.config": could not resolve child component ".config")"}
            );
        }

        SUBCASE("lute_modules")
        {
            doPassingSubcase(argv, {"./lute/lute"}, {"successfully required @lute modules"});
        }

        SUBCASE("std_modules")
        {
            doPassingSubcase(argv, {"./lute/std"}, {"successfully required @std modules"});
        }
    }
}

TEST_CASE("require_with_parent_ambiguity")
{
    // This test case cannot be included in the general "require_modules" test
    // because ambiguity prevents the test's requirer.luau from navigating to
    // this test's entry point. Instead, we manually start the entry point here.

    char executablePlaceholder[] = "lute";

    // .luaurc
    for (const std::string& luteProjectRoot : {getLuteProjectRootRelative(), getLuteProjectRootAbsolute()})
    {
        std::string requirer = joinPaths(luteProjectRoot, "tests/src/require/config_tests/with_config/src/parent_ambiguity/folder/requirer.luau");
        std::vector<char*> argv = {executablePlaceholder, requirer.data()};
        CHECK_EQ(cliMain(argv.size(), argv.data()), 0);
    }

    // .config.luau
    for (const std::string& luteProjectRoot : {getLuteProjectRootRelative(), getLuteProjectRootAbsolute()})
    {
        std::string requirer =
            joinPaths(luteProjectRoot, "tests/src/require/config_tests/with_config_luau/src/parent_ambiguity/folder/requirer.luau");
        std::vector<char*> argv = {executablePlaceholder, requirer.data()};
        CHECK_EQ(cliMain(argv.size(), argv.data()), 0);
    }
}

TEST_CASE("require_types")
{
    char executablePlaceholder[] = "lute";
    for (const std::string& luteProjectRoot : {getLuteProjectRootRelative(), getLuteProjectRootAbsolute()})
    {
        std::string requirer = joinPaths(luteProjectRoot, "tests/src/require/without_config/types/tester.luau");
        std::vector<char*> argv = {executablePlaceholder, requirer.data()};

        CHECK_EQ(cliMain(argv.size(), argv.data()), 0);
    }
}

TEST_CASE("require_by_string_semantics_in_cli")
{
    char executablePlaceholder[] = "lute";

    // Expected to pass
    for (const std::string& luteProjectRoot : {getLuteProjectRootRelative(), getLuteProjectRootAbsolute()})
    {
        std::vector<std::string> inputPaths = {
            joinPaths(luteProjectRoot, "tests/src/require/without_config/nested"),
            joinPaths(luteProjectRoot, "tests/src/require/without_config/nested/init.luau"),
            joinPaths(luteProjectRoot, "tests/src/require/without_config/nested/submodule"),
            joinPaths(luteProjectRoot, "tests/src/require/without_config/nested/submodule.luau"),
        };

        for (std::string& inputPath : inputPaths)
        {
            std::vector<char*> argv = {executablePlaceholder, inputPath.data()};
            CHECK_EQ(cliMain(argv.size(), argv.data()), 0);
        }
    }

    // Expected to fail
    for (const std::string& luteProjectRoot : {getLuteProjectRootRelative(), getLuteProjectRootAbsolute()})
    {
        std::string inputPath = joinPaths(luteProjectRoot, "tests/src/require/without_config/nested/init");
        std::vector<char*> argv = {executablePlaceholder, inputPath.data()};
        CHECK_NE(cliMain(argv.size(), argv.data()), 0);
    }
}
