#include "lute/require.h"

#include "lute/clivfs.h"
#include "lute/modulepath.h"
#include "lute/options.h"

#include "lua.h"
#include "lualib.h"

#include "Luau/Compiler.h"
#include "Luau/CodeGen.h"
#include "Luau/Require.h"
#include "Luau/StringUtils.h"
#include <string>

static luarequire_WriteResult write(std::optional<std::string> contents, char* buffer, size_t bufferSize, size_t* sizeOut)
{
    if (!contents)
        return luarequire_WriteResult::WRITE_FAILURE;

    size_t nullTerminatedSize = contents->size() + 1;

    if (bufferSize < nullTerminatedSize)
    {
        *sizeOut = nullTerminatedSize;
        return luarequire_WriteResult::WRITE_BUFFER_TOO_SMALL;
    }

    *sizeOut = nullTerminatedSize;
    memcpy(buffer, contents->c_str(), nullTerminatedSize);
    return luarequire_WriteResult::WRITE_SUCCESS;
}

static luarequire_NavigateResult convert(NavigationStatus status)
{
    if (status == NavigationStatus::Success)
        return NAVIGATE_SUCCESS;

    if (status == NavigationStatus::Ambiguous)
        return NAVIGATE_AMBIGUOUS;

    return NAVIGATE_NOT_FOUND;
}

static bool is_require_allowed(lua_State* L, void* ctx, const char* requirer_chunkname)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    return reqCtx->vfs.isRequireAllowed(L, requirer_chunkname);
}

static luarequire_NavigateResult reset(lua_State* L, void* ctx, const char* requirer_chunkname)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    return convert(reqCtx->vfs.reset(L, requirer_chunkname));
}

static luarequire_NavigateResult jump_to_alias(lua_State* L, void* ctx, const char* path)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    return convert(reqCtx->vfs.jumpToAlias(L, path));
}

static luarequire_NavigateResult to_parent(lua_State* L, void* ctx)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    return convert(reqCtx->vfs.toParent(L));
}

static luarequire_NavigateResult to_child(lua_State* L, void* ctx, const char* name)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    return convert(reqCtx->vfs.toChild(L, name));
}

static bool is_module_present(lua_State* L, void* ctx)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    return reqCtx->vfs.isModulePresent(L);
}

static luarequire_WriteResult get_chunkname(lua_State* L, void* ctx, char* buffer, size_t buffer_size, size_t* size_out)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    return write(reqCtx->vfs.getChunkname(L), buffer, buffer_size, size_out);
}

static luarequire_WriteResult get_loadname(lua_State* L, void* ctx, char* buffer, size_t buffer_size, size_t* size_out)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    return write(reqCtx->vfs.getLoadname(L), buffer, buffer_size, size_out);
}

static luarequire_WriteResult get_cache_key(lua_State* L, void* ctx, char* buffer, size_t buffer_size, size_t* size_out)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    return write(reqCtx->vfs.getCacheKey(L), buffer, buffer_size, size_out);
}

static bool is_config_present(lua_State* L, void* ctx)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    return reqCtx->vfs.isConfigPresent(L);
}

static luarequire_WriteResult get_config(lua_State* L, void* ctx, char* buffer, size_t buffer_size, size_t* size_out)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    return write(reqCtx->vfs.getConfig(L), buffer, buffer_size, size_out);
}

static int load(lua_State* L, void* ctx, const char* path, const char* chunkname, const char* loadname)
{
    // module needs to run in a new thread, isolated from the rest
    // note: we create ML on main thread so that it doesn't inherit environment of L
    lua_State* GL = lua_mainthread(L);
    lua_State* ML = lua_newthread(GL);
    lua_xmove(GL, L, 1);

    // new thread needs to have the globals sandboxed
    luaL_sandboxthread(ML);

    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    std::optional<std::string> contents = reqCtx->vfs.getContents(L, loadname);
    if (!contents)
        luaL_error(L, "could not read file '%s'", loadname);

    // now we can compile & run module on the new thread
    std::string bytecode = Luau::compile(*contents, copts());
    if (luau_load(ML, chunkname, bytecode.data(), bytecode.size(), 0) == 0)
    {
        if (getCodegenEnabled())
        {
            Luau::CodeGen::CompilationOptions nativeOptions;
            Luau::CodeGen::compile(ML, -1, nativeOptions);
        }

        int status = lua_resume(ML, L, 0);

        if (status == 0)
        {
            const std::string prefix = "module " + std::string(path) + " must";

            if (lua_gettop(ML) == 0)
                lua_pushstring(ML, (prefix + " return a value, if it has no return value, you should explicitly return `nil`\n").c_str());
        }
        else if (status == LUA_YIELD)
        {
            lua_pushstring(ML, "module can not yield\n");
        }
        else if (!lua_isstring(ML, -1))
        {
            lua_pushstring(ML, "unknown error while running module\n");
        }
    }

    // add ML result to L stack
    lua_xmove(ML, L, 1);
    if (lua_isstring(L, -1))
    {
        lua_pushstring(L, lua_debugtrace(ML));
        lua_concat(L, 2);
        lua_error(L);
    }

    // remove ML thread from L stack
    lua_remove(L, -2);

    // added one value to L stack: module result
    return 1;
}

void requireConfigInit(luarequire_Configuration* config)
{
    if (config == nullptr)
        return;

    config->is_require_allowed = is_require_allowed;
    config->reset = reset;
    config->jump_to_alias = jump_to_alias;
    config->to_parent = to_parent;
    config->to_child = to_child;
    config->is_module_present = is_module_present;
    config->is_config_present = is_config_present;
    config->get_chunkname = get_chunkname;
    config->get_loadname = get_loadname;
    config->get_cache_key = get_cache_key;
    config->get_config = get_config;
    config->get_alias = nullptr; // We use get_config instead of get_alias.
    config->load = load;
}

RequireCtx::RequireCtx()
    : vfs()
{
}

RequireCtx::RequireCtx(CliVfs cliVfs)
    : vfs(cliVfs)
{
}
