#include "lute/climain.h"
#include "lute/options.h"
#include "lute/packagerequirevfs.h"
#include "lute/require.h"
#include "lute/runtime.h"
#include "lute/userlandvfs.h"

#include "Luau/FileUtils.h"
#include "Luau/Require.h"

#include "lua.h"
#include "lualib.h"

#include <memory>
#include <string>
#include <vector>

#include "doctest.h"
#include "lutefixture.h"
#include "luteprojectroot.h"

TEST_CASE_FIXTURE(LuteFixture, "package_aware_require")
{
    Runtime runtime{getReporter()};

    setupState(
        runtime,
        [](lua_State* L)
        {
            std::string luteProjectRoot = getLuteProjectRootAbsolute();
            std::string entryRoot = luteProjectRoot + '/' + "tests/src/packages/package_aware_require/packageentry";

            std::vector<Package::Identifier> directDependencies = {
                {"dep", "2.0.0"},
            };

            std::string packagesRoot = luteProjectRoot + '/' + "tests/src/packages/package_aware_require";
            std::vector<std::pair<Package::Identifier, Package::Info>> allDependencies;
            allDependencies.push_back(
                {{"dep", "1.0.0"},
                 {
                     packagesRoot + '/' + "internaldep",
                     {},
                 }}
            );
            allDependencies.push_back(
                {{"dep", "2.0.0"},
                 {
                     packagesRoot + '/' + "dep",
                     {{"dep", "1.0.0"}},
                 }}
            );

            Package::UserlandVfs userlandVfs = Package::UserlandVfs::create(std::move(directDependencies), std::move(allDependencies));

            void* ctx = lua_newuserdatadtor(
                L,
                sizeof(RequireCtx),
                [](lua_State*, void* ptr)
                {
                    static_cast<RequireCtx*>(ptr)->~RequireCtx();
                }
            );

            if (!ctx)
                luaL_errorL(L, "unable to allocate RequireCtx");

            ctx = new (ctx) RequireCtx{std::make_unique<Package::RequireVfs>(std::move(userlandVfs))};

            // Store RequireCtx in the registry to keep it alive for the lifetime of
            // this lua_State. Memory address is used as a key to avoid collisions.
            lua_pushlightuserdata(L, ctx);
            lua_insert(L, -2);
            lua_settable(L, LUA_REGISTRYINDEX);

            luaopen_require(L, requireConfigInit, ctx);
        }
    );

    std::string path = getLuteProjectRootAbsolute() + "/tests/src/packages/package_aware_require/packageentry/entry.luau";
    std::optional<std::string> contents = readFile(path);
    REQUIRE(contents);

    bool success = runtime.runSource(*contents, copts(), "@" + path);
    CHECK(success);
}

TEST_CASE_FIXTURE(LuteFixture, "pkgrun_with_lockfile")
{
    std::string entry = getLuteProjectRootAbsolute() + "/tests/src/packages/pkgrun_with_lockfile/packageentry/entry.luau";

    char executablePlaceholder[] = "lute";
    char command[] = "pkg";
    char subcommand[] = "run";
    std::vector<char*> argv = {executablePlaceholder, command, subcommand, entry.data()};

    CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
    auto rep = getReporter();
}

TEST_CASE_FIXTURE(LuteFixture, "pkgrun_transitive_deps")
{
    std::string entry = getLuteProjectRootAbsolute() + "/tests/src/packages/pkgrun_transitive_deps/packageentry/entry.luau";

    char executablePlaceholder[] = "lute";
    char command[] = "pkg";
    char subcommand[] = "run";
    std::vector<char*> argv = {executablePlaceholder, command, subcommand, entry.data()};

    CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
}

TEST_CASE_FIXTURE(LuteFixture, "pkgrun_resolves_divergent_transitive_revisions_in_one_run")
{
    std::string entry = getLuteProjectRootAbsolute() + "/tests/src/packages/pkgrun_divergent_transitive_deps/packageentry/entry.luau";

    char executablePlaceholder[] = "lute";
    char command[] = "pkg";
    char subcommand[] = "run";
    std::vector<char*> argv = {executablePlaceholder, command, subcommand, entry.data()};

    CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
    CHECK(getReporter().getErrors().empty());
}

TEST_CASE_FIXTURE(LuteFixture, "pkgrun_deep_path_deps")
{
    std::string entry = getLuteProjectRootAbsolute() + "/tests/src/packages/pkgrun_deep_path_deps/packageentry/entry.luau";

    char executablePlaceholder[] = "lute";
    char command[] = "pkg";
    char subcommand[] = "run";
    std::vector<char*> argv = {executablePlaceholder, command, subcommand, entry.data()};

    CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
}

TEST_CASE_FIXTURE(LuteFixture, "pkgrun_uses_registry_lockfile_identity_and_root_alias")
{
    std::string entry = getLuteProjectRootAbsolute() + "/tests/src/packages/pkgrun_registry_identity/packageentry/entry.luau";

    char executablePlaceholder[] = "lute";
    char command[] = "pkg";
    char subcommand[] = "run";
    std::vector<char*> argv = {executablePlaceholder, command, subcommand, entry.data()};

    CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
}

TEST_CASE_FIXTURE(LuteFixture, "pkgrun_uses_the_member_dependencies_from_a_virtual_root_lockfile")
{
    std::string entry = getLuteProjectRootAbsolute() + "/tests/src/packages/pkgrun_virtual_manifest/modules/second/src/main.luau";

    char executablePlaceholder[] = "lute";
    char command[] = "pkg";
    char subcommand[] = "run";
    std::vector<char*> argv = {executablePlaceholder, command, subcommand, entry.data()};

    CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
}

static void checkMalformedLockfileFails(LuteFixture& fixture, const std::string& scenario, const std::string& expectedError)
{
    std::string entry = getLuteProjectRootAbsolute() + "/tests/src/packages/pkgrun_malformed_lockfile/" + scenario + "/packageentry/entry.luau";

    char executablePlaceholder[] = "lute";
    char command[] = "pkg";
    char subcommand[] = "run";
    std::vector<char*> argv = {executablePlaceholder, command, subcommand, entry.data()};

    CHECK_EQ(cliMain(argv.size(), argv.data(), fixture.getReporter()), 1);

    const std::vector<std::string>& errors = fixture.getReporter().getErrors();
    REQUIRE_EQ(errors.size(), 1);
    CHECK(errors[0].find("Invalid lockfile") != std::string::npos);
    CHECK(errors[0].find("pkg.lock.luau") != std::string::npos);
    CHECK(errors[0].find(expectedError) != std::string::npos);
}

TEST_CASE_FIXTURE(LuteFixture, "pkgrun_fails_on_lockfile_with_invalid_syntax")
{
    checkMalformedLockfileFails(*this, "invalid_syntax", "config:5");
}

TEST_CASE_FIXTURE(LuteFixture, "pkgrun_fails_on_lockfile_missing_dependencies")
{
    checkMalformedLockfileFails(*this, "missing_dependencies", "missing required field 'dependencies'");
}

TEST_CASE_FIXTURE(LuteFixture, "pkgrun_fails_on_lockfile_with_non_table_packages")
{
    checkMalformedLockfileFails(*this, "non_table_packages", "field 'packages' must be a table");
}

TEST_CASE_FIXTURE(LuteFixture, "pkgrun_fails_on_lockfile_package_missing_name")
{
    checkMalformedLockfileFails(*this, "missing_name", "package 'dep@1.0.0' is missing required field 'name'");
}

TEST_CASE_FIXTURE(LuteFixture, "pkgrun_does_not_match_install_roots_by_raw_string_prefix")
{
    std::string entry = getLuteProjectRootAbsolute() + "/tests/src/packages/pkgrun_overlapping_roots/prefix/packageentry/entry.luau";

    char executablePlaceholder[] = "lute";
    char command[] = "pkg";
    char subcommand[] = "run";
    std::vector<char*> argv = {executablePlaceholder, command, subcommand, entry.data()};

    CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
    CHECK(getReporter().getErrors().empty());
}

TEST_CASE_FIXTURE(LuteFixture, "pkgrun_uses_the_most_specific_install_root_for_nested_packages")
{
    std::string entry = getLuteProjectRootAbsolute() + "/tests/src/packages/pkgrun_overlapping_roots/nested/packageentry/entry.luau";

    char executablePlaceholder[] = "lute";
    char command[] = "pkg";
    char subcommand[] = "run";
    std::vector<char*> argv = {executablePlaceholder, command, subcommand, entry.data()};

    CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
    CHECK(getReporter().getErrors().empty());
}

TEST_CASE_FIXTURE(LuteFixture, "pkgrun_lockfile_aliases_are_directory_aliases")
{
    std::string entry = getLuteProjectRootAbsolute() + "/tests/src/packages/pkgrun_directory_aliases/packageentry/entry.luau";

    char executablePlaceholder[] = "lute";
    char command[] = "pkg";
    char subcommand[] = "run";
    std::vector<char*> argv = {executablePlaceholder, command, subcommand, entry.data()};

    CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
    CHECK(getReporter().getErrors().empty());
}
