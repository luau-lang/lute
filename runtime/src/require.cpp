#include "lute/require.h"

#include "lute/options.h"
#include "lute/requireutils.h"

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

static luarequire_NavigateResult storePathResult(RequireCtx* reqCtx, PathResult result)
{
    if (result.status == PathResult::Status::AMBIGUOUS)
        return NAVIGATE_AMBIGUOUS;

    if (result.status == PathResult::Status::NOT_FOUND)
        return NAVIGATE_NOT_FOUND;

    reqCtx->absPath = result.absPath;
    reqCtx->relPath = result.relPath;
    reqCtx->suffix = result.suffix;

    return NAVIGATE_SUCCESS;
}

static bool is_require_allowed(lua_State* L, void* ctx, const char* requirer_chunkname)
{
    // FIXME: this is a temporary workaround until Luau.Require provides a way
    // to perform proxy requires.
    return true;

    // std::string_view chunkname = requirer_chunkname;
    // bool isStdin = (chunkname == "=stdin");
    // bool isFile = (!chunkname.empty() && chunkname[0] == '@');
    // bool isStdLibFile = (chunkname.size() >= 6 && chunkname.substr(0, 6) == "@@std/");
    // return isStdin || isFile || isStdLibFile;
}

static luarequire_NavigateResult reset(lua_State* L, void* ctx, const char* requirer_chunkname)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);

    std::string chunkname = reqCtx->sourceOverride ? *reqCtx->sourceOverride : requirer_chunkname;
    reqCtx->atFakeRoot = false;

    if ((chunkname.size() >= 6 && chunkname.substr(0, 6) == "@@std/"))
    {
        reqCtx->currentVFSType = VFSType::Std;
        reqCtx->absPath = chunkname.substr(1);
        return storePathResult(reqCtx, getAbsolutePathResult(reqCtx->currentVFSType, chunkname.substr(1)));
    }
    else
    {
        reqCtx->currentVFSType = VFSType::Disk;
        if (chunkname == "=stdin")
        {
            return storePathResult(reqCtx, getStdInResult());
        }
        else if (!chunkname.empty() && chunkname[0] == '@')
        {
            return storePathResult(reqCtx, tryGetRelativePathResult(chunkname.substr(1)));
        }
    }

    return NAVIGATE_NOT_FOUND;
}

static luarequire_NavigateResult jump_to_alias(lua_State* L, void* ctx, const char* path)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);

    // FIXME: this is a temporary workaround until Luau.Require provides an
    // API for registering the @lute/* libraries.
    if (std::string_view(path) == "$lute")
    {
        reqCtx->atFakeRoot = false;
        reqCtx->currentVFSType = VFSType::Lute;
        reqCtx->absPath = "@lute";
        reqCtx->relPath = "";
        reqCtx->suffix = "";
        return NAVIGATE_SUCCESS;
    }

    if (std::string_view(path) == "$std")
    {
        reqCtx->atFakeRoot = false;
        reqCtx->currentVFSType = VFSType::Std;
        reqCtx->absPath = "@std";
        reqCtx->relPath = "";
        reqCtx->suffix = "";
        return NAVIGATE_SUCCESS;
    }

    luarequire_NavigateResult result = storePathResult(reqCtx, getAbsolutePathResult(reqCtx->currentVFSType, path));
    if (result != NAVIGATE_SUCCESS)
        return result;

    // Jumping to an absolute path breaks the relative-require chain. The best
    // we can do is to store the absolute path itself.
    reqCtx->relPath = reqCtx->absPath;
    return NAVIGATE_SUCCESS;
}

static luarequire_NavigateResult to_parent(lua_State* L, void* ctx)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);

    PathResult result = getParent(reqCtx->currentVFSType, reqCtx->absPath, reqCtx->relPath);
    if (result.status == PathResult::Status::NOT_FOUND)
    {
        if (reqCtx->atFakeRoot)
            return NAVIGATE_NOT_FOUND;

        reqCtx->atFakeRoot = true;
        return NAVIGATE_SUCCESS;
    }

    return storePathResult(reqCtx, result);
}

static luarequire_NavigateResult to_child(lua_State* L, void* ctx, const char* name)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    reqCtx->atFakeRoot = false;
    return storePathResult(reqCtx, getChild(reqCtx->currentVFSType, reqCtx->absPath, reqCtx->relPath, name));
}

static bool is_module_present(lua_State* L, void* ctx)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);

    // FIXME: this is a temporary workaround until Luau.Require provides an
    // API for registering the @lute/* libraries.
    if (reqCtx->currentVFSType == VFSType::Lute)
        return true;

    return isFilePresent(reqCtx->currentVFSType, reqCtx->absPath, reqCtx->suffix);
}

static luarequire_WriteResult get_contents(lua_State* L, void* ctx, char* buffer, size_t buffer_size, size_t* size_out)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);

    // FIXME: this is a temporary workaround until Luau.Require provides an
    // API for registering the @lute/* libraries.
    if (reqCtx->currentVFSType == VFSType::Lute)
        return write("", buffer, buffer_size, size_out);

    return write(getFileContents(reqCtx->currentVFSType, reqCtx->absPath, reqCtx->suffix), buffer, buffer_size, size_out);
}

static luarequire_WriteResult get_chunkname(lua_State* L, void* ctx, char* buffer, size_t buffer_size, size_t* size_out)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);

    // FIXME: this is a temporary workaround until Luau.Require provides an
    // API for registering the @lute/* libraries.
    if (reqCtx->currentVFSType == VFSType::Lute)
        return write("@" + reqCtx->absPath, buffer, buffer_size, size_out);

    if (reqCtx->currentVFSType == VFSType::Std)
        return write("@" + reqCtx->absPath, buffer, buffer_size, size_out);

    return write("@" + reqCtx->relPath, buffer, buffer_size, size_out);
}

static luarequire_WriteResult get_cache_key(lua_State* L, void* ctx, char* buffer, size_t buffer_size, size_t* size_out)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    return write(reqCtx->absPath + reqCtx->suffix, buffer, buffer_size, size_out);
}

static bool is_config_present(lua_State* L, void* ctx)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    if (reqCtx->atFakeRoot)
        return true;

    // FIXME: this is a temporary workaround until Luau.Require provides an
    // API for registering the @lute/* libraries.
    if (reqCtx->currentVFSType == VFSType::Lute)
        return false;

    return isFilePresent(reqCtx->currentVFSType, reqCtx->absPath, "/.luaurc");
}

static luarequire_WriteResult get_config(lua_State* L, void* ctx, char* buffer, size_t buffer_size, size_t* size_out)
{
    RequireCtx* reqCtx = static_cast<RequireCtx*>(ctx);
    if (reqCtx->atFakeRoot)
    {
        std::string globalConfig = "{\n"
                                    "    \"aliases\": {\n"
                                    "        \"std\": \"$std\",\n"
                                    "        \"lute\": \"$lute\",\n"
                                    "    }\n"
                                    "}\n";
        return write(globalConfig, buffer, buffer_size, size_out);
    }

    return write(getFileContents(reqCtx->currentVFSType, reqCtx->absPath, "/.luaurc"), buffer, buffer_size, size_out);
}

static int load(lua_State* L, void* ctx, const char* chunkname, const char* contents)
{
    std::string_view chunknameView = chunkname;

    // FIXME: this is a temporary workaround until Luau.Require provides an
    // API for registering the @lute/* libraries.
    if (chunknameView.rfind("@@lute/", 0) == 0)
    {
        lua_getfield(L, LUA_REGISTRYINDEX, "_MODULES");
        lua_getfield(L, -1, chunknameView.substr(1).data());

        if (lua_isnil(L, -1))
        {
            lua_pop(L, 1);
            luaL_error(L, "no luau runtime library: %s", &chunkname[1]);
        }

        return 1;
    }

    // module needs to run in a new thread, isolated from the rest
    // note: we create ML on main thread so that it doesn't inherit environment of L
    lua_State* GL = lua_mainthread(L);
    lua_State* ML = lua_newthread(GL);
    lua_xmove(GL, L, 1);

    // new thread needs to have the globals sandboxed
    luaL_sandboxthread(ML);

    // now we can compile & run module on the new thread
    std::string bytecode = Luau::compile(contents, copts());
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
            const std::string prefix = "module " + std::string(chunknameView.substr(1)) + " must";

            if (lua_gettop(ML) == 0)
                lua_pushstring(ML, (prefix + " return a value").c_str());
            else if (!lua_istable(ML, -1) && !lua_isfunction(ML, -1))
                lua_pushstring(ML, (prefix + " return a table or function").c_str());
        }
        else if (status == LUA_YIELD)
        {
            lua_pushstring(ML, "module can not yield");
        }
        else if (!lua_isstring(ML, -1))
        {
            lua_pushstring(ML, "unknown error while running module");
        }
    }

    // add ML result to L stack
    lua_xmove(ML, L, 1);
    if (lua_isstring(L, -1))
        lua_error(L);

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
    config->get_contents = get_contents;
    config->is_config_present = is_config_present;
    config->get_chunkname = get_chunkname;
    config->get_cache_key = get_cache_key;
    config->get_config = get_config;
    config->load = load;
}
