#include "lute/fs.h"

#include "lute/runtime.h"
#include "lute/time.h"
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

#include <sys/stat.h>


#if !defined(S_ISREG) && defined(S_IFMT) && defined(S_IFREG)
#define S_ISREG(m) (((m) & S_IFMT) == S_IFREG)
#endif

#if !defined(S_ISDIR) && defined(S_IFMT) && defined(S_IFDIR)
#define S_ISDIR(m) (((m) & S_IFMT) == S_IFDIR)
#endif

#if !defined(S_ISCHR) && defined(S_IFMT) && defined(S_IFCHR)
#define S_ISCHR(m) (((m) & S_IFMT) == S_IFCHR)
#endif

#if !defined(S_ISLNK) && defined(S_IFMT) && defined(S_IFLNK)
#define S_ISLNK(m) (((m) & S_IFMT) == S_IFLNK)
#endif

#if !defined(S_ISFIFO) && defined(S_IFMT) && defined(S_IFIFO)
#define S_ISFIFO(m) (((m) & S_IFMT) == S_IFIFO)
#endif

namespace fs
{

const char* UV_TYPENAME_UNKNOWN = "unknown"; // UV_DIRENT_UNKNOWN
const char* UV_TYPENAME_FILE = "file";       // UV_DIRENT_FILE
const char* UV_TYPENAME_DIR = "dir";         // UV_DIRENT_DIR
const char* UV_TYPENAME_LINK = "link";       // UV_DIRENT_LINK
const char* UV_TYPENAME_FIFO = "fifo";       // UV_DIRENT_FIFO
const char* UV_TYPENAME_SOCKET = "socket";   // UV_DIRENT_SOCKET
const char* UV_TYPENAME_CHAR = "char";       // UV_DIRENT_CHAR
const char* UV_TYPENAME_BLOCK = "block";     // UV_DIRENT_BLOCK

const char* UV_DIRENT_TYPES[] = {
    UV_TYPENAME_UNKNOWN,
    UV_TYPENAME_FILE,
    UV_TYPENAME_DIR,
    UV_TYPENAME_LINK,
    UV_TYPENAME_FIFO,
    UV_TYPENAME_SOCKET,
    UV_TYPENAME_CHAR,
    UV_TYPENAME_BLOCK,
};

static UVFile* getFileHandle(lua_State* L, int index)
{
    if (!lua_islightuserdata(L, index))
    {
        luaL_errorL(L, "Error: expected file handle");
        return nullptr;
    }

    auto* handle = static_cast<UVFile*>(lua_tolightuserdata(L, index));
    if (!handle)
    {
        luaL_errorL(L, "Error: invalid file handle");
        return nullptr;
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

static int createDurationFromTimespec32(lua_State* L, uv_timespec_t timespec)
{
    uv_timespec64_t extended{static_cast<int64_t>(timespec.tv_sec), static_cast<int32_t>(timespec.tv_nsec)};
    return createDurationFromTimespec(L, extended);
}

static const char* fileModeToType(uint64_t mode)
{
    if (S_ISDIR(mode))
    {
        return UV_TYPENAME_DIR;
    }
    else if (S_ISREG(mode))
    {
        return UV_TYPENAME_FILE;
    }
    else if (S_ISCHR(mode))
    {
        return UV_TYPENAME_CHAR;
    }
    else if (S_ISLNK(mode))
    {
        return UV_TYPENAME_LINK;
    }
#ifdef S_ISBLK
    else if (S_ISBLK(mode))
    {
        return UV_TYPENAME_BLOCK;
    }
#endif
#ifdef S_ISFIFO
    else if (S_ISFIFO(mode))
    {
        return UV_TYPENAME_FIFO;
    }
#endif
#ifdef S_ISSOCK
    else if (S_ISSOCK(mode))
    {
        return UV_TYPENAME_SOCKET;
    }
#endif
    else
    {
        return UV_TYPENAME_UNKNOWN;
    }
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
        return 0;
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
        return 0;
    }

    return open_impl(L, path, openFlags, *modeFlags);
}

int fs_remove(lua_State* L)
{
    uv_fs_t unlink_req;
    int err = uv_fs_unlink(uv_default_loop(), &unlink_req, luaL_checkstring(L, 1), nullptr);
    uv_fs_req_cleanup(&unlink_req);

    if (err)
        luaL_errorL(L, "%s", uv_strerror(err));

    return 0;
}

int fs_mkdir(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    int mode = luaL_optinteger(L, 2, 0777);

    uv_fs_t req;
    int err = uv_fs_mkdir(uv_default_loop(), &req, path, mode, nullptr);
    uv_fs_req_cleanup(&req);

    if (err)
        luaL_errorL(L, "%s", uv_strerror(err));

    return 0;
}

int fs_rmdir(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    uv_fs_t rmdir_req;
    int err = uv_fs_rmdir(uv_default_loop(), &rmdir_req, path, nullptr);
    uv_fs_req_cleanup(&rmdir_req);

    if (err)
        luaL_errorL(L, "%s", uv_strerror(err));

    return 0;
}

int fs_stat(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    uv_fs_t stat_req;
    int err = uv_fs_stat(uv_default_loop(), &stat_req, path, nullptr);

    if (err)
    {
        uv_fs_req_cleanup(&stat_req);
        luaL_errorL(L, "%s", uv_strerror(err));
    }

    lua_createtable(L, 0, 6);

    auto stat = stat_req.statbuf;

    auto type = fileModeToType(stat.st_mode);
    lua_pushstring(L, type);
    lua_setfield(L, -2, "type");

    // this is fine unless the file is 9 petabytes
    lua_pushnumber(L, static_cast<double>(stat.st_size));
    lua_setfield(L, -2, "size");

    createDurationFromTimespec32(L, stat.st_birthtim);
    lua_setfield(L, -2, "created");

    createDurationFromTimespec32(L, stat.st_atim);
    lua_setfield(L, -2, "accessed");

    createDurationFromTimespec32(L, stat.st_mtim);
    lua_setfield(L, -2, "modified");

    // permissions
    lua_createtable(L, 0, 2);

    // libuv writes this correctly cross-platform
    bool canAnyWrite = stat.st_mode & 0222;
    lua_pushboolean(L, !canAnyWrite);
    lua_setfield(L, -2, "readonly");

    lua_setfield(L, -2, "permissions");

    uv_fs_req_cleanup(&stat_req);

    return 1;
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

    uv_fs_t req;

    int err = uv_fs_stat(uv_default_loop(), &req, path, nullptr);

    if (err)
    {
        uv_fs_req_cleanup(&req);
        luaL_errorL(L, "%s", uv_strerror(err));
    }

    auto type = fileModeToType(req.statbuf.st_mode);
    lua_pushstring(L, type);
    uv_fs_req_cleanup(&req);

    return 1;
}

int listdir(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    auto* req = new uv_fs_t();
    req->data = new ResumeToken(getResumeToken(L));

    int err = uv_fs_scandir(
        uv_default_loop(),
        req,
        path,
        0,
        [](uv_fs_t* req)
        {
            auto* request_state = static_cast<ResumeToken*>(req->data);

            request_state->get()->complete(
                [req](lua_State* L)
                {
                    lua_createtable(L, 1, 0);

                    uv_dirent_t dir;
                    int i = 0;
                    int err = 0;
                    while ((err = uv_fs_scandir_next(req, &dir)) >= 0)
                    {
                        lua_pushinteger(L, ++i);

                        lua_createtable(L, 0, 2);

                        lua_pushstring(L, dir.name);
                        lua_setfield(L, -2, "name");

                        lua_pushstring(L, UV_DIRENT_TYPES[dir.type]);
                        lua_setfield(L, -2, "type");

                        lua_settable(L, -3);
                    }

                    uv_fs_req_cleanup(req);

                    delete static_cast<ResumeToken*>(req->data);
                    delete req;

                    if (err != UV_EOF)
                        luaL_errorL(L, "%s", uv_strerror(err));

                    return 1;
                }
            );
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
