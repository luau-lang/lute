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

static void* createRunRequireContext(lua_State* L)
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

    ctx = new (ctx) RequireCtx{std::make_unique<RequireVfs>()};

    // Store RequireCtx in the registry to keep it alive for the lifetime of
    // this lua_State. Memory address is used as a key to avoid collisions.
    lua_pushlightuserdata(L, ctx);
    lua_insert(L, -2);
    lua_settable(L, LUA_REGISTRYINDEX);

    return ctx;
}

static void* createCliCommandRequireContext(lua_State* L)
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

static void* createPkgRunRequireContext(
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
    Luau::DenseHashMap<std::string, std::string> luauConfigFiles,
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
    ctx = new (ctx) RequireCtx{std::make_unique<RequireVfs>(BundleVfs{std::move(luauConfigFiles), std::move(bundleMap)})};

    // Store RequireCtx in the registry to keep it alive for the lifetime of
    // this lua_State. Memory address is used as a key to avoid collisions.
    lua_pushlightuserdata(L, ctx);
    lua_insert(L, -2);
    lua_settable(L, LUA_REGISTRYINDEX);

    return ctx;
}

lua_State* setupRunState(Runtime& runtime, std::function<void(lua_State*)> preSandboxInit)
{
    runtime.requireContextFactory = createRunRequireContext;

    return setupState(
        runtime,
        [preSandboxInit = std::move(preSandboxInit)](lua_State* L)
        {
            if (Luau::CodeGen::isSupported())
                Luau::CodeGen::create(L);

            luaopen_require(L, requireConfigInit, createRunRequireContext(L));
            if (preSandboxInit)
                preSandboxInit(L);
        }
    );
}

lua_State* setupCliCommandState(Runtime& runtime, std::function<void(lua_State*)> preSandboxInit)
{
    runtime.requireContextFactory = createCliCommandRequireContext;

    return setupState(
        runtime,
        [preSandboxInit = std::move(preSandboxInit)](lua_State* L)
        {
            if (Luau::CodeGen::isSupported())
                Luau::CodeGen::create(L);

            luaopen_require(L, requireConfigInit, createCliCommandRequireContext(L));
            if (preSandboxInit)
                preSandboxInit(L);
        }
    );
}

struct PkgData
{
    std::vector<Package::Identifier> directDependencies;
    std::vector<std::pair<Package::Identifier, Package::Info>> allDependencies;
};

lua_State* setupPkgRunState(
    Runtime& runtime,
    std::vector<Package::Identifier> directDependencies,
    std::vector<std::pair<Package::Identifier, Package::Info>> allDependencies
)
{
    std::shared_ptr<PkgData> pkgData = std::make_shared<PkgData>(PkgData{std::move(directDependencies), std::move(allDependencies)});
    runtime.requireContextFactory = [pkgData = std::move(pkgData)](lua_State* L) -> void*
    {
        return createPkgRunRequireContext(L, pkgData->directDependencies, pkgData->allDependencies);
    };

    return setupState(
        runtime,
        [&factory = runtime.requireContextFactory](lua_State* L)
        {
            if (Luau::CodeGen::isSupported())
                Luau::CodeGen::create(L);

            luaopen_require(L, requireConfigInit, factory(L));
        }
    );
}

struct BundleData
{
    Luau::DenseHashMap<std::string, std::string> luauConfigFiles;
    Luau::DenseHashMap<std::string, std::string> bundleMap;
};

lua_State* setupBundleState(
    Runtime& runtime,
    Luau::DenseHashMap<std::string, std::string> luauConfigFiles,
    Luau::DenseHashMap<std::string, std::string> bundleMap
)
{
    std::shared_ptr<BundleData> bundleData = std::make_shared<BundleData>(BundleData{std::move(luauConfigFiles), std::move(bundleMap)});
    runtime.requireContextFactory = [bundleData = std::move(bundleData)](lua_State* L) -> void*
    {
        return createBundleRequireContext(L, bundleData->luauConfigFiles, bundleData->bundleMap);
    };

    return setupState(
        runtime,
        [&factory = runtime.requireContextFactory](lua_State* L)
        {
            if (Luau::CodeGen::isSupported())
                Luau::CodeGen::create(L);

            luaopen_require(L, requireConfigInit, factory(L));
        }
    );
}
