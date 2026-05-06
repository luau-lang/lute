#include "lute/fs.h"

#include "lute/runtime.h"
#include "lute/time.h"
#include "lute/userdatas.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include <cstring>
#include <memory>
#include <optional>
#include <string>

#include "fs_impl.h"

namespace fs
{

static UVFile* getFileHandle(lua_State* L, int index)
{
    auto* handle = static_cast<UVFile*>(lua_touserdatatagged(L, index, kUVFileTag));
    if (!handle)
    {
        luaL_errorL(L, "Error: expected file handle");
    }

    return handle;
}

std::optional<int> setFlags(const char* modeStr, int* openFlags)
{
    int modeFlags = 0x0000;

    for (const char* it = modeStr; *it != '\0'; it++)
    {
        char modeChar = *it;
        switch (modeChar)
        {
        case 'r':
            *openFlags |= O_RDONLY;
            break;
        case 'w':
            *openFlags |= O_WRONLY | O_TRUNC | O_CREAT;
            modeFlags = 0666;
            break;
        case 'x':
            *openFlags |= O_WRONLY | O_CREAT | O_EXCL;
            modeFlags = 0666;
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
    const char* path = luaL_checkstring(L, 1);

    int openFlags = 0x0000;
    const char* mode = "r";
    if (!lua_isnoneornil(L, 2))
        mode = luaL_checkstring(L, 2);

    std::optional<int> modeFlags = setFlags(mode, &openFlags);
    if (!modeFlags)
    {
        luaL_errorL(L, "Error decoding mode: %s\n", mode);
    }

    return open_impl(L, path, openFlags, *modeFlags);
}

int remove(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    return remove_impl(L, path);
}

int mkdir(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    return mkdir_impl(L, path, 0777);
}

int rmdir(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    return rmdir_impl(L, path);
}

int stat(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    return stat_impl(L, path);
}

int copy(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    const char* dest = luaL_checkstring(L, 2);
    return copy_impl(L, path, dest);
}

int link(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    const char* dest = luaL_checkstring(L, 2);
    return link_impl(L, path, dest);
}

int symlink(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    const char* dest = luaL_checkstring(L, 2);
    return symlink_impl(L, path, dest);
}

int rename(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    const char* dest = luaL_checkstring(L, 2);
    return rename_impl(L, path, dest);
}

struct WatchHandle
{
    WatchHandle(lua_State* L, int callbackIdx)
        : runtime(getRuntime(L))
        , callbackReference(std::make_shared<Ref>(L, callbackIdx))
        , evtHandle(std::make_unique<uv_fs_event_t>())
    {
        evtHandle->data = this;
        int err = uv_fs_event_init(runtime->getEventLoop(), evtHandle.get());
        if (err)
            luaL_errorL(L, "%s", uv_strerror(err));
    }

    Runtime* runtime;
    std::shared_ptr<Ref> callbackReference;
    bool isClosed = false;
    std::unique_ptr<uv_fs_event_t> evtHandle;

    void close()
    {
        if (!isClosed)
        {

            isClosed = true;
            uv_fs_event_stop(evtHandle.get());
            callbackReference.reset();
            auto raw = evtHandle.release();
            uv_close(
                (uv_handle_t*)raw,
                [](uv_handle_t* handle)
                {
                    delete (uv_fs_event_t*)handle;
                }
            );
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

    void* storage = lua_newuserdatataggedwithmetatable(L, sizeof(WatchHandle), kWatchHandleTag);
    auto* event = new (storage) WatchHandle(L, 2);

    int event_start_err = uv_fs_event_start(
        event->evtHandle.get(),
        [](uv_fs_event_t* handle, const char* filenamePtr, int events, int status)
        {
            auto* eventHandle = static_cast<WatchHandle*>(handle->data);

            if (status < 0)
                return;

            std::string filename = filenamePtr ? filenamePtr : "";

            eventHandle->runtime->scheduleLuauCallback(
                eventHandle->callbackReference,
                [filename = std::move(filename), events](lua_State* L)
                {
                    lua_pushlstring(L, filename.c_str(), filename.size());

                    lua_createtable(L, 0, 2);
                    lua_pushboolean(L, (events & UV_RENAME) != 0);
                    lua_setfield(L, -2, "rename");
                    lua_pushboolean(L, (events & UV_CHANGE) != 0);
                    lua_setfield(L, -2, "change");

                    return 2;
                }
            );
        },
        path,
        0
    );

    if (event_start_err)
    {
        luaL_errorL(L, "%s", uv_strerror(event_start_err));
    }

    return 1; // return the watch handle
}

int exists(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    return exists_impl(L, path);
}

int type(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    return type_impl(L, path);
}

int listdir(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    return listdir_impl(L, path);
}

} // namespace fs

static void initializeFS(lua_State* L)
{
    init_duration_lib(L);

    luaL_newmetatable(L, "FileHandle");
    lua_pushstring(L, "FileHandle");
    lua_setfield(L, -2, "__type");
    lua_setuserdatadtor(
        L,
        kUVFileTag,
        [](lua_State*, void* ud)
        {
            auto* file = static_cast<fs::UVFile*>(ud);
            if (file->fd.has_value())
            {
                uv_fs_t req;
                uv_fs_close(nullptr, &req, *file->fd, nullptr);
                uv_fs_req_cleanup(&req);
            }
            std::destroy_at(file);
        }
    );
    lua_setuserdatametatable(L, kUVFileTag);

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

const char* const FS::properties[] = {nullptr};

const luaL_Reg FS::lib[] = {
    {"open", fs::open},
    {"read", fs::read},
    {"write", fs::write},
    {"close", fs::close},

    {"remove", fs::remove},

    {"stat", fs::stat},
    {"exists", fs::exists},
    {"type", fs::type},

    {"watch", fs::fs_watch},
    {"link", fs::link},
    {"symlink", fs::symlink},
    {"copy", fs::copy},
    {"move", fs::rename},

    {"mkdir", fs::mkdir},
    {"listdir", fs::listdir},
    {"rmdir", fs::rmdir},

    {nullptr, nullptr},
};

int FS::pushLibrary(lua_State* L)
{
    lua_createtable(L, 0, std::size(FS::lib));

    for (auto& [name, func] : FS::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    initializeFS(L);

    return 1;
}

LUTE_API int luaopen_fs(lua_State* L)
{
    return FS::openAsGlobal(L);
}

LUTE_API int luteopen_fs(lua_State* L)
{
    return FS::pushLibrary(L);
}
