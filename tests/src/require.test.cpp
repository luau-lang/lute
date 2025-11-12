#include "lute/climain.h"
#include "lute/uvutils.h"

#include "Luau/FileUtils.h"

#include "lua.h"

#include "uv.h"

#include <filesystem>
#include <fstream>

#include "cliruntimefixture.h"
#include "doctest.h"
#include "lutefixture.h"
#include "luteprojectroot.h"


TEST_CASE_FIXTURE(CliRuntimeFixture, "require_exists")
{
    lua_getglobal(L, "require");
    CHECK(!lua_isnil(L, -1));
}

TEST_CASE_FIXTURE(LuteFixture, "require_modules")
{
    auto doPassingSubcase = [&](std::vector<char*> argv, std::string requirePath, std::vector<std::string> expectedResults)
    {
        std::string pass = "pass";
        argv.push_back(pass.data());
        argv.push_back(requirePath.data());
        for (std::string& result : expectedResults)
        {
            argv.push_back(result.data());
        }
        CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
    };

    auto doFailingSubcase = [&](std::vector<char*> argv, std::string requirePath, std::vector<std::string> expectedResults)
    {
        std::string fail = "fail";
        argv.push_back(fail.data());
        argv.push_back(requirePath.data());
        for (std::string& result : expectedResults)
        {
            argv.push_back(result.data());
        }
        CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
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

TEST_CASE_FIXTURE(LuteFixture, "require_with_parent_ambiguity")
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
        CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
    }

    // .config.luau
    for (const std::string& luteProjectRoot : {getLuteProjectRootRelative(), getLuteProjectRootAbsolute()})
    {
        std::string requirer =
            joinPaths(luteProjectRoot, "tests/src/require/config_tests/with_config_luau/src/parent_ambiguity/folder/requirer.luau");
        std::vector<char*> argv = {executablePlaceholder, requirer.data()};
        CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
    }
}

TEST_CASE_FIXTURE(LuteFixture, "require_types")
{
    char executablePlaceholder[] = "lute";
    for (const std::string& luteProjectRoot : {getLuteProjectRootRelative(), getLuteProjectRootAbsolute()})
    {
        std::string requirer = joinPaths(luteProjectRoot, "tests/src/require/without_config/types/tester.luau");
        std::vector<char*> argv = {executablePlaceholder, requirer.data()};

        CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
    }
}

TEST_CASE_FIXTURE(LuteFixture, "require_by_string_semantics_in_cli")
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
            CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
        }
    }

    // Expected to fail
    for (const std::string& luteProjectRoot : {getLuteProjectRootRelative(), getLuteProjectRootAbsolute()})
    {
        std::string inputPath = joinPaths(luteProjectRoot, "tests/src/require/without_config/nested/init");
        std::vector<char*> argv = {executablePlaceholder, inputPath.data()};
        CHECK_NE(cliMain(argv.size(), argv.data(), getReporter()), 0);
    }
}

TEST_CASE_FIXTURE(LuteFixture, "require_check_tilde_path")
{
    char executablePlaceholder[] = "lute";
    char subCommand[] = "check";
    // Get home directory
    auto result = uvutils::getStringFromUv(uv_os_homedir);
    REQUIRE(result.get_if<std::string>() != nullptr);
    std::string homeDir = *result.get_if<std::string>();

    // Create test directory and test file
    std::filesystem::path testDir = std::filesystem::path(homeDir) / "lute_test_special";
    std::filesystem::path testFile = testDir / "foo.luau";
    std::filesystem::create_directories(testDir);

    // Write test module file
    std::ofstream file(testFile);
    REQUIRE(file.is_open());
    file << "return { foo = \"bar\" }\n";
    file.close();

    // Run the test
    for (const std::string& luteProjectRoot : {getLuteProjectRootRelative(), getLuteProjectRootAbsolute()})
    {
        std::string mainPath = joinPaths(luteProjectRoot, "tests/src/require/config_tests/tilde_config/main.luau");
        std::vector<char*> argv = {executablePlaceholder, subCommand, mainPath.data()};
        CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
    }

    // Clean up
    std::filesystem::remove(testFile);
    std::filesystem::remove(testDir);
}
