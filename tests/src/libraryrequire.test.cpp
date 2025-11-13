#include "lute/climain.h"
#include "lute/options.h"
#include "lute/packagerequirevfs.h"
#include "lute/require.h"
#include "lute/runtime.h"
#include "lute/userlandvfs.h"

#include "Luau/Compiler.h"
#include "Luau/FileUtils.h"
#include "Luau/Require.h"

#include "lua.h"
#include "lualib.h"

#include <memory>

#include "doctest.h"
#include "lutefixture.h"
#include "luteprojectroot.h"

TEST_CASE_FIXTURE(LuteFixture, "package_aware_require")
{
    Runtime runtime;

    lua_State* L = setupState(
        runtime,
        [](lua_State* L)
        {
            std::string luteProjectRoot = getLuteProjectRootAbsolute();
            std::string entryRoot = luteProjectRoot + '/' + "tests/src/packages/packageentry";

            std::vector<Package::Identifier> directDependencies = {
                {"dep", "2.0.0"},
            };

            std::string librariesRoot = luteProjectRoot + '/' + "tests/src/packages";
            std::vector<std::pair<Package::Identifier, Package::Info>> libraries;
            libraries.push_back(
                {{"dep", "1.0.0"},
                 {
                     librariesRoot + '/' + "internaldep",
                     librariesRoot + '/' + "internaldep/init.luau",
                     {},
                 }}
            );
            libraries.push_back(
                {{"dep", "2.0.0"},
                 {
                     librariesRoot + '/' + "dep",
                     librariesRoot + '/' + "dep/module.luau",
                     {{"dep", "1.0.0"}},
                 }}
            );

            Package::UserlandVfs libraryVfs = Package::UserlandVfs::create(std::move(directDependencies), std::move(libraries));

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

            ctx = new (ctx) RequireCtx{std::make_unique<Package::RequireVfs>(std::move(libraryVfs))};

            // Store RequireCtx in the registry to keep it alive for the lifetime of
            // this lua_State. Memory address is used as a key to avoid collisions.
            lua_pushlightuserdata(L, ctx);
            lua_insert(L, -2);
            lua_settable(L, LUA_REGISTRYINDEX);

            luaopen_require(L, requireConfigInit, ctx);
        }
    );

    std::string path = getLuteProjectRootAbsolute() + "/tests/src/packages/packageentry/entry.luau";
    std::optional<std::string> contents = readFile(path);
    REQUIRE(contents);

    std::string bytecode = Luau::compile(*contents, copts());
    bool success = runBytecode(runtime, bytecode, "@" + path, L, 0, nullptr, getReporter());
    CHECK(success);
}
