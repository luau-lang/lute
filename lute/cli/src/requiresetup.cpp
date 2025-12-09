#include "lute/requiresetup.h"

#include "lute/bundlevfs.h"
#include "lute/clivfs.h"
#include "lute/crypto.h"
#include "lute/fs.h"
#include "lute/io.h"
#include "lute/luau.h"
#include "lute/net.h"
#include "lute/process.h"
#include "lute/require.h"
#include "lute/requirevfs.h"
#include "lute/runtime.h"
#include "lute/system.h"
#include "lute/task.h"
#include "lute/time.h"
#include "lute/vm.h"

#include "Luau/CodeGen.h"
#include "Luau/Require.h"

static void luteopen_libs(lua_State* L)
{
    std::vector<std::pair<const char*, lua_CFunction>> libs = {{
        {"@lute/crypto", luteopen_crypto},
        {"@lute/fs", luteopen_fs},
        {"@lute/luau", luteopen_luau},
        {"@lute/net", luteopen_net},
        {"@lute/process", luteopen_process},
        {"@lute/task", luteopen_task},
        {"@lute/vm", luteopen_vm},
        {"@lute/system", luteopen_system},
        {"@lute/time", luteopen_time},
        {"@lute/io", luteopen_io},
    }};

    for (const auto& [name, func] : libs)
    {
        lua_pushcfunction(L, luarequire_registermodule, nullptr);
        lua_pushstring(L, name);
        func(L);
        lua_call(L, 2, 0);
    }
}

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
            luteopen_libs(L);

            if (Luau::CodeGen::isSupported())
                Luau::CodeGen::create(L);

            luaopen_require(L, requireConfigInit, createCliRequireContext(L));
            if (preSandboxInit)
                preSandboxInit(L);
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
            luteopen_libs(L);
            if (Luau::CodeGen::isSupported())
                Luau::CodeGen::create(L);

            luaopen_require(L, requireConfigInit, createBundleRequireContext(L, std::move(luaurcFiles), std::move(bundleMap)));
        }
    );
}
