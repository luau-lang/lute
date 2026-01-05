#include "lute/requiresetup.h"

#include "lute/bundlevfs.h"
#include "lute/clivfs.h"
#include "lute/packagerequirevfs.h"
#include "lute/require.h"
#include "lute/requirevfs.h"
#include "lute/runtime.h"
#include "lute/userlandvfs.h"

#include "Luau/CodeGen.h"
#include "Luau/Require.h"

#include "lualib.h"

#include <memory>
#include <string>
#include <utility>

static void* createCliRequireContext(lua_State* L)
{
    void* ctx = lua_newuserdatadtor(
        L,
        sizeof(RequireCtx),
        [](void* ptr)
        {
            std::destroy_at(static_cast<RequireCtx*>(ptr));
        }
    );

    if (!ctx)
        luaL_error(L, "unable to allocate RequireCtx");

    ctx = new (ctx) RequireCtx{std::make_unique<RequireVfs>(CliVfs{})};

    // Store RequireCtx in the registry to keep it alive for the lifetime of
    // this lua_State. Memory address is used as a key to avoid collisions.
    lua_pushlightuserdata(L, ctx);
    lua_insert(L, -2);
    lua_settable(L, LUA_REGISTRYINDEX);

    return ctx;
}

static void* createPkgRequireContext(
    lua_State* L,
    std::vector<Package::Identifier> directDependencies,
    std::vector<std::pair<Package::Identifier, Package::Info>> allDependencies
)
{
    void* ctx = lua_newuserdatadtor(
        L,
        sizeof(RequireCtx),
        [](void* ptr)
        {
            std::destroy_at(static_cast<RequireCtx*>(ptr));
        }
    );

    if (!ctx)
        luaL_error(L, "unable to allocate RequireCtx");

    Package::UserlandVfs userlandVfs = Package::UserlandVfs::create(std::move(directDependencies), std::move(allDependencies));
    ctx = new (ctx) RequireCtx{std::make_unique<Package::RequireVfs>(std::move(userlandVfs))};

    // Store RequireCtx in the registry to keep it alive for the lifetime of
    // this lua_State. Memory address is used as a key to avoid collisions.
    lua_pushlightuserdata(L, ctx);
    lua_insert(L, -2);
    lua_settable(L, LUA_REGISTRYINDEX);

    return ctx;
}

static void* createBundleRequireContext(
    lua_State* L,
    Luau::DenseHashMap<std::string, std::string> luaurcFiles,
    Luau::DenseHashMap<std::string, std::string> bundleMap
)
{
    void* ctx = lua_newuserdatadtor(
        L,
        sizeof(RequireCtx),
        [](void* ptr)
        {
            std::destroy_at(static_cast<RequireCtx*>(ptr));
        }
    );

    if (!ctx)
        luaL_error(L, "unable to allocate RequireCtx");
    ctx = new (ctx) RequireCtx{std::make_unique<RequireVfs>(BundleVfs{std::move(luaurcFiles), std::move(bundleMap)})};

    // Store RequireCtx in the registry to keep it alive for the lifetime of
    // this lua_State. Memory address is used as a key to avoid collisions.
    lua_pushlightuserdata(L, ctx);
    lua_insert(L, -2);
    lua_settable(L, LUA_REGISTRYINDEX);

    return ctx;
}

lua_State* setupCliState(Runtime& runtime, std::function<void(lua_State*)> preSandboxInit)
{
    return setupState(
        runtime,
        [preSandboxInit = std::move(preSandboxInit)](lua_State* L)
        {
            if (Luau::CodeGen::isSupported())
                Luau::CodeGen::create(L);

            luaopen_require(L, requireConfigInit, createCliRequireContext(L));
            if (preSandboxInit)
                preSandboxInit(L);
        }
    );
}

lua_State* setupPkgCliState(
    Runtime& runtime,
    std::vector<Package::Identifier> directDependencies,
    std::vector<std::pair<Package::Identifier, Package::Info>> allDependencies
)
{
    return setupState(
        runtime,
        [directDependencies = std::move(directDependencies), allDependencies = std::move(allDependencies)](lua_State* L)
        {
            if (Luau::CodeGen::isSupported())
                Luau::CodeGen::create(L);

            luaopen_require(L, requireConfigInit, createPkgRequireContext(L, std::move(directDependencies), std::move(allDependencies)));
        }
    );
}

lua_State* setupBundleState(
    Runtime& runtime,
    Luau::DenseHashMap<std::string, std::string> luaurcFiles,
    Luau::DenseHashMap<std::string, std::string> bundleMap
)
{
    return setupState(
        runtime,
        [luaurcFiles = std::move(luaurcFiles), bundleMap = std::move(bundleMap)](lua_State* L)
        {
            if (Luau::CodeGen::isSupported())
                Luau::CodeGen::create(L);

            luaopen_require(L, requireConfigInit, createBundleRequireContext(L, std::move(luaurcFiles), std::move(bundleMap)));
        }
    );
}
