#include "Luau/FileUtils.h"
#include "doctest.h"

#include "lute/climain.h"
#include "lute/require.h"
#include "lute/runtime.h"

#include "Luau/Require.h"

#include "lua.h"
#include "lualib.h"
#include "luteprojectroot.h"

#include <memory>

class CliRuntimeFixture
{
public:
    CliRuntimeFixture()
        : runtime(std::make_unique<Runtime>())
    {
        L = setupCliState(*runtime);
    }

    lua_State* L;

private:
    std::unique_ptr<Runtime> runtime;
};

TEST_CASE_FIXTURE(CliRuntimeFixture, "require_exists")
{
    lua_getglobal(L, "require");
    CHECK(!lua_isnil(L, -1));
}

TEST_CASE("require_modules")
{
    auto doPassingSubcase = [](std::vector<char*>& argv, std::string requirePath, std::vector<std::string> expectedResults)
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

    auto doFailingSubcase = [](std::vector<char*>& argv, std::string requirePath, std::vector<std::string> expectedResults)
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
            doPassingSubcase(argv, {"./with_config/src/alias_requirer"}, {"result from dependency"});
        }

        SUBCASE("with_directory_alias")
        {
            doPassingSubcase(argv, {"./with_config/src/directory_alias_requirer"}, {"result from subdirectory_dependency"});
        }

        SUBCASE("with_parent_configuration_alias")
        {
            doPassingSubcase(argv, {"./with_config/src/parent_alias_requirer"}, {"result from other_dependency"});
        }

        SUBCASE("init_does_not_read_sibling_luaurc")
        {
            doPassingSubcase(argv, {"./with_config/src/submodule"}, {"result from dependency"});
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
