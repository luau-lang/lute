#include "doctest.h"

#include "luteprojectroot.h"

#include "lute/climain.h"
#include "lute/libraryrequirevfs.h"
#include "lute/libraryvfs.h"
#include "lute/options.h"
#include "lute/require.h"
#include "lute/runtime.h"

#include "Luau/Compiler.h"
#include "Luau/FileUtils.h"
#include "Luau/Require.h"

#include "lua.h"
#include "lualib.h"

#include <memory>

TEST_CASE("library_aware_require")
{
    Runtime runtime;

    lua_State* L = setupState(
        runtime,
        [](lua_State* L)
        {
            std::string luteProjectRoot = getLuteProjectRootAbsolute();
            std::string entryRoot = luteProjectRoot + '/' + "tests/src/libraryentry";

            std::vector<Library::Identifier> directDependencies = {
                {"dep", "2.0.0"},
            };

            std::string librariesRoot = luteProjectRoot + '/' + "tests/src/libraries";
            std::vector<std::pair<Library::Identifier, Library::Info>> libraries;
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

            Library::Vfs libraryVfs = Library::Vfs::create(std::move(directDependencies), std::move(libraries));

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

            ctx = new (ctx) RequireCtx{std::make_unique<Library::RequireVfs>(std::move(libraryVfs))};

            // Store RequireCtx in the registry to keep it alive for the lifetime of
            // this lua_State. Memory address is used as a key to avoid collisions.
            lua_pushlightuserdata(L, ctx);
            lua_insert(L, -2);
            lua_settable(L, LUA_REGISTRYINDEX);

            luaopen_require(L, requireConfigInit, ctx);
        }
    );

    std::string path = getLuteProjectRootAbsolute() + "/tests/src/libraryentry/entry.luau";
    std::optional<std::string> contents = readFile(path);
    REQUIRE(contents);

    std::string bytecode = Luau::compile(*contents, copts());
    bool success = runBytecode(runtime, bytecode, "@" + path, L, 0, nullptr);
    CHECK(success);
}
