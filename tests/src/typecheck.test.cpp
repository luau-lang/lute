#include "lute/tc.h"

#include "Luau/FileUtils.h"

#include "doctest.h"
#include "lutefixture.h"
#include "luteprojectroot.h"

TEST_CASE_FIXTURE(LuteFixture, "typecheck_uses_new_solver")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/staticrequires/newsolver.luau");

    auto result = typecheck({testFilePath}, getReporter());
    CHECK(result == 0);
}

TEST_CASE_FIXTURE(LuteFixture, "typecheck_all_builtins")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/typecheck/all_builtins.luau");

    auto result = typecheck({testFilePath}, getReporter());
    CHECK(result == 0);
}

TEST_CASE_FIXTURE(LuteFixture, "typecheck_user_code_doesnt_pass_with_batteries")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/typecheck/batteries_failure.luau");

    auto result = typecheck({testFilePath}, getReporter());
    CHECK(result == 1);
}

TEST_CASE_FIXTURE(LuteFixture, "typecheck_with_definitions_succeeds")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/typecheck/definitions_success/user_code.luau");
    std::string configPath = joinPaths(luteProjectRoot, "tests/src/typecheck/definitions_success/.config.luau");

    auto result = typecheck({testFilePath}, getReporter(), configPath);
    CHECK(result == 0);
}

TEST_CASE_FIXTURE(LuteFixture, "typecheck_without_definitions_fails")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/typecheck/definitions_success/user_code.luau");

    auto result = typecheck({testFilePath}, getReporter());
    CHECK(result == 1);
}

TEST_CASE_FIXTURE(LuteFixture, "typecheck_definition_file_not_found")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/typecheck/definitions_missing/user_code.luau");
    std::string configPath = joinPaths(luteProjectRoot, "tests/src/typecheck/definitions_missing/.config.luau");

    auto result = typecheck({testFilePath}, getReporter(), configPath);
    CHECK(result == 1);
}

TEST_CASE_FIXTURE(LuteFixture, "typecheck_definition_file_parse_error")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testFilePath = joinPaths(luteProjectRoot, "tests/src/typecheck/definitions_invalid/user_code.luau");
    std::string configPath = joinPaths(luteProjectRoot, "tests/src/typecheck/definitions_invalid/.config.luau");

    auto result = typecheck({testFilePath}, getReporter(), configPath);
    CHECK(result == 1);
}
