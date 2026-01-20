#include "lute/fs.h"

#include "lute/runtime.h"
#include "lute/userdatas.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include <cstdio>
#include <cstring>

#include "fs_impl.h"
#ifdef _WIN32
#include <direct.h>
#else
#include <unistd.h>
#endif
#include <fcntl.h>
#include <filesystem>
#include <map>
#include <memory>
#include <optional>
#include <stdlib.h>
#include <string>

namespace fs
{

static UVFile* getFileHandle(lua_State* L, int index)
{
    if (!lua_islightuserdata(L, index))
    {
        luaL_errorL(L, "Error: expected file handle");
    }

    auto* handle = static_cast<UVFile*>(lua_tolightuserdata(L, index));
    if (!handle)
    {
        luaL_errorL(L, "Error: invalid file handle");
    }

    return handle;
}

std::optional<int> setFlags(const char* c, int* openFlags)
{
    int modeFlags = 0x0000;

    for (const char* it = c; *it != '\0'; it++)
    {
        char c = *it;
        switch (c)
        {
        case 'r':
            *openFlags |= O_RDONLY;
            break;
        case 'w':
            *openFlags |= O_WRONLY | O_TRUNC;
            break;
        case 'x':
            *openFlags |= O_CREAT | O_EXCL;
            modeFlags = 0700;
            break;
        case 'a':
            *openFlags |= O_WRONLY | O_APPEND;
            break;
        case '+':
            // If we have not set the truncate bit in 'w' mode,
            *openFlags &= ~O_RDONLY;
            *openFlags &= ~O_WRONLY;
            *openFlags |= O_RDWR;

            if ((*openFlags & O_TRUNC))
            {
                *openFlags |= O_CREAT;
                modeFlags = 0000700 | 0000070 | 0000007;
            }
            break;
        default:
            return std::nullopt;
        }
    }

    return modeFlags;
}

int close(lua_State* L)
{
    auto* handle = getFileHandle(L, 1);
    return close_impl(L, handle);
}

int read(lua_State* L)
{
    auto* handle = getFileHandle(L, 1);
    return read_impl(L, handle);
}

int write(lua_State* L)
{
    auto* handle = getFileHandle(L, 1);

    size_t len;
    const char* data = luaL_checklstring(L, 2, &len);

    return write_impl(L, handle, data, len);
}

int open(lua_State* L)
{
    int nArgs = lua_gettop(L);
    if (nArgs < 1)
    {
        luaL_errorL(L, "Error: no file supplied\n");
    }
    const char* path = luaL_checkstring(L, 1);

    int openFlags = 0x0000;
    const char* mode = "r";
    // Default to read mode if no mode is supplied (i.e., mode is nil in Luau)
    if (nArgs < 2 || lua_isnil(L, 2))
    {
        openFlags = O_RDONLY;
    }
    else
    {
        mode = luaL_checkstring(L, 2);
    }

    std::optional<int> modeFlags = setFlags(mode, &openFlags);
    if (!modeFlags)
    {
        luaL_errorL(L, "Error decoding mode: %s\n", mode);
    }

    return open_impl(L, path, openFlags, *modeFlags);
}

int remove(lua_State* L)
{
    int nArgs = lua_gettop(L);
    if (nArgs < 1)
    {
        luaL_errorL(L, "Error: no file supplied\n");
    }

    if (nArgs > 1)
    {
        luaL_errorL(L, "Error: too many arguments supplied\n");
    }
    const char* path = luaL_checkstring(L, 1);

    return remove_impl(L, path);
}

int mkdir(lua_State* L)
{
    int nArgs = lua_gettop(L);
    if (nArgs < 1)
    {
        luaL_errorL(L, "Error: no path supplied\n");
    }

    if (nArgs > 2)
    {
        luaL_errorL(L, "Error: too many arguments supplied\n");
    }
    const char* path = luaL_checkstring(L, 1);
    int mode = luaL_optinteger(L, 2, 0777);

    return mkdir_impl(L, path, mode);
}

int rmdir(lua_State* L)
{
    int nArgs = lua_gettop(L);
    if (nArgs < 1)
    {
        luaL_errorL(L, "rmdir: no path supplied\n");
    }

    if (nArgs > 1)
    {
        luaL_errorL(L, "rmdir: too many arguments supplied\n");
    }

    const char* path = luaL_checkstring(L, 1);

    return rmdir_impl(L, path);
}

int stat(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    return stat_impl(L, path);
}

static void defaultCallback(uv_fs_t* req)
{
    auto* request_state = static_cast<ResumeToken*>(req->data);
    auto token = std::move(*request_state);
    delete request_state;

    auto err = req->result;

    uv_fs_req_cleanup(req);
    delete req;

    if (err)
    {
        token->fail(uv_strerror(err));
        return;
    }

    token->complete(
        [](lua_State* L)
        {
            return 0;
        }
    );
}

int fs_copy(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    const char* dest = luaL_checkstring(L, 2);

    auto* req = new uv_fs_t();
    req->data = new ResumeToken(getResumeToken(L));

    int err = uv_fs_copyfile(uv_default_loop(), req, path, dest, 0, defaultCallback);

    if (err)
    {
        delete static_cast<ResumeToken*>(req->data);
        delete req;
        luaL_errorL(L, "%s", uv_strerror(err));
    }

    return lua_yield(L, 0);
}

int fs_link(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    const char* dest = luaL_checkstring(L, 2);

    auto* req = new uv_fs_t();
    req->data = new ResumeToken(getResumeToken(L));

    int err = uv_fs_link(uv_default_loop(), req, path, dest, defaultCallback);

    if (err)
    {
        delete static_cast<ResumeToken*>(req->data);
        delete req;
        luaL_errorL(L, "%s", uv_strerror(err));
    }

    return lua_yield(L, 0);
}

int fs_symlink(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    const char* dest = luaL_checkstring(L, 2);

    auto* req = new uv_fs_t();
    req->data = new ResumeToken(getResumeToken(L));

    if (std::filesystem::is_directory(path))
    {
        req->flags = UV_FS_SYMLINK_DIR; // windows
    }
    else
    {
        req->flags = 0;
    }

    int err = uv_fs_symlink(uv_default_loop(), req, path, dest, req->flags, defaultCallback);

    if (err)
    {
        delete static_cast<ResumeToken*>(req->data);
        delete req;
        luaL_errorL(L, "%s", uv_strerror(err));
    }

    return lua_yield(L, 0);
}

struct WatchHandle
{
    lua_State* L;
    std::shared_ptr<Ref> callbackReference;
    bool isClosed = false;
    uv_fs_event_t handle;

    void close()
    {
        if (!isClosed)
        {
            int err = uv_fs_event_stop(&handle);
            if (err)
            {
                luaL_errorL(L, "Error stopping fs event: %s", uv_strerror(err));
            }

            uv_close((uv_handle_t*)&handle, nullptr);

            isClosed = true;

            getRuntime(L)->releasePendingToken();

            callbackReference.reset();
        }
    }

    ~WatchHandle()
    {
        close();
    }
};

static int closeWatchHandle(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handle = static_cast<WatchHandle*>(lua_touserdatatagged(L, 1, kWatchHandleTag));

    if (!handle)
    {
        luaL_errorL(L, "Invalid fs event handle");
        return 0;
    }

    handle->close();

    return 0;
}

int fs_watch(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);

    auto* event = new (static_cast<WatchHandle*>(lua_newuserdatataggedwithmetatable(L, sizeof(WatchHandle), kWatchHandleTag))) WatchHandle{};

    event->L = L;
    event->callbackReference = std::make_shared<Ref>(L, 2);
    event->handle.data = event;

    int init_err = uv_fs_event_init(uv_default_loop(), &event->handle);

    if (init_err)
    {
        luaL_errorL(L, "%s", uv_strerror(init_err));
    }

    int event_start_err = uv_fs_event_start(
        &event->handle,
        [](uv_fs_event_t* handle, const char* filenamePtr, int events, int status)
        {
            auto* eventHandle = static_cast<WatchHandle*>(handle->data);

            lua_State* newThread = lua_newthread(eventHandle->L);
            std::shared_ptr<Ref> ref = getRefForThread(newThread);
            Runtime* runtime = getRuntime(newThread);

            std::string filename = filenamePtr ? filenamePtr : "";

            runtime->scheduleLuauResume(
                ref,
                [=, filename = std::move(filename)](lua_State* L)
                {
                    // the function to the back of the stack, omit from nret
                    eventHandle->callbackReference->push(L);

                    // filename
                    lua_pushlstring(L, filename.c_str(), filename.size());

                    // events
                    lua_createtable(L, 0, 2);

                    lua_pushboolean(L, (events & UV_RENAME) != 0);
                    lua_setfield(L, -2, "rename");
                    lua_pushboolean(L, (events & UV_CHANGE) != 0);
                    lua_setfield(L, -2, "change");

                    return 2;
                }
            );

            uv_stop(handle->loop);
        },
        path,
        0
    );

    if (event_start_err)
    {
        luaL_errorL(L, "%s", uv_strerror(event_start_err));
    }

    getRuntime(L)->addPendingToken();

    return 1; // return the watch handle
}

int fs_exists(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    auto* req = new uv_fs_t();
    req->data = new ResumeToken(getResumeToken(L));

    int err = uv_fs_access(
        uv_default_loop(),
        req,
        path,
        F_OK,
        [](uv_fs_t* req)
        {
            auto* request_state = static_cast<ResumeToken*>(req->data);

            request_state->get()->complete(
                [req](lua_State* L)
                {
                    lua_pushboolean(L, req->result == 0);
                    uv_fs_req_cleanup(req);

                    delete req;

                    return 1;
                }
            );
            delete request_state;
        }
    );

    if (err)
    {
        delete static_cast<ResumeToken*>(req->data);
        delete req;
        luaL_errorL(L, "%s", uv_strerror(err));
    }

    return lua_yield(L, 0);
}

int type(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    return type_impl(L, path);
}

int listdir(lua_State* L)
{
    int nArgs = lua_gettop(L);
    if (nArgs > 1)
    {
        luaL_errorL(L, "listdir: too many arguments supplied\n");
    }

    const char* path = luaL_checkstring(L, 1);

    return listdir_impl(L, path);
}

} // namespace fs

static void initalizeFS(lua_State* L)
{
    luaL_newmetatable(L, "WatchHandle");

    lua_pushcfunction(
        L,
        [](lua_State* L)
        {
            const char* index = luaL_checkstring(L, -1);

            if (strcmp(index, "close") == 0)
            {
                lua_pushcfunction(L, fs::closeWatchHandle, "WatchHandle.close");

                return 1;
            }

            return 0;
        },
        "WatchHandle.__index"
    );
    lua_setfield(L, -2, "__index");

    lua_pushstring(L, "WatchHandle");
    lua_setfield(L, -2, "__type");

    lua_setuserdatadtor(
        L,
        kWatchHandleTag,
        [](lua_State* L, void* ud)
        {
            std::destroy_at(static_cast<fs::WatchHandle*>(ud));
        }
    );

    lua_setuserdatametatable(L, kWatchHandleTag);
}

int luaopen_fs(lua_State* L)
{
    luaL_register(L, "fs", fs::lib);
    initalizeFS(L);
    return 1;
}

int luteopen_fs(lua_State* L)
{
    lua_createtable(L, 0, std::size(fs::lib));

    for (auto& [name, func] : fs::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    initalizeFS(L);

    return 1;
}
