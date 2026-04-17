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
                     packagesRoot + '/' + "internaldep/init.luau",
                     {},
                 }}
            );
            allDependencies.push_back(
                {{"dep", "2.0.0"},
                 {
                     packagesRoot + '/' + "dep",
                     packagesRoot + '/' + "dep/module.luau",
                     {{"dep", "1.0.0"}},
                 }}
            );

            Package::UserlandVfs userlandVfs = Package::UserlandVfs::create(std::move(directDependencies), std::move(allDependencies));

            void* ctx = lua_newuserdatadtor(
                L,
                sizeof(RequireCtx),
                [](void* ptr)
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

TEST_CASE_FIXTURE(LuteFixture, "pkgrun_deep_path_deps")
{
    std::string entry = getLuteProjectRootAbsolute() + "/tests/src/packages/pkgrun_deep_path_deps/packageentry/entry.luau";

    char executablePlaceholder[] = "lute";
    char command[] = "pkg";
    char subcommand[] = "run";
    std::vector<char*> argv = {executablePlaceholder, command, subcommand, entry.data()};

    CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
}
