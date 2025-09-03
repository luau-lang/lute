#include "lute/fs.h"

#include "Luau/Common.h"
#include "lua.h"
#include "lualib.h"
#include "lute/async.h"
#include "lute/exception.h"
#include "lute/ref.h"
#include "uv.h"

#include "lute/runtime.h"
#include "lute/time.h"
#include "lute/userdatas.h"

#include <array>
#include <cstddef>
#include <cstdio>
#include <cstring>
#ifdef _WIN32
#include <direct.h>
#endif
#include <fcntl.h>
#include <filesystem>
#include <map>
#include <memory>
#include <string>
#include <stdlib.h>


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

int setFlags(const char* c, int* openFlags)
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
            throw LuteException{"Invalid file mode"};
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

struct FileHandle
{
    ssize_t fileDescriptor = -1;
    int errcode = -1;
};

l_noret luaL_errorHandle(lua_State* L, FileHandle& handle)
{
#ifdef _MSC_VER
    luaL_errorL(L, "Error writing to file with descriptor %Iu\n", handle.fileDescriptor);
#else
    luaL_errorL(L, "Error writing to file with descriptor %zu\n", handle.fileDescriptor);
#endif
}

void setfield(lua_State* L, const char* index, int value)
{
    lua_pushstring(L, index);
    lua_pushinteger(L, value);
    lua_settable(L, -3);
}

void createFileHandle(lua_State* L, const FileHandle& toCreate)
{
    lua_newtable(L);

    setfield(L, "fd", toCreate.fileDescriptor);
    setfield(L, "err", toCreate.errcode);
}

FileHandle unpackFileHandle(lua_State* L)
{
    FileHandle result;

    luaL_checktype(L, 1, LUA_TTABLE);
    lua_getfield(L, 1, "fd");
    lua_getfield(L, 1, "err");

    ssize_t fd = luaL_checkinteger(L, -2);
    int err = luaL_checknumber(L, -1);
    result.fileDescriptor = fd;
    result.errcode = err;

    lua_pop(L, 2); // we got the args by value, so we can clean up the stack here

    return result;
}


template<typename... Args>
class SimpleFSOperation
    : public Task
    , public UVAsyncOperation<uv_fs_t>
{
public:
    using UVFunction = int (*)(uv_loop_t*, uv_fs_t*, Args..., uv_fs_cb);

    SimpleFSOperation(Runtime* runtime, lua_State* L, UVFunction uv_fn, Args... args)
        : Task{runtime, L}
        , UVAsyncOperation<uv_fs_t>{}
        , uv_fn{uv_fn}
        , args{std::make_tuple(args...)}
    {
    }

    void start() override
    {
        int err = std::apply(
            [this](auto&&... unpackedArgs)
            {
                return uv_fn(uv_default_loop(), getRequest(), unpackedArgs..., uv_async_callback);
            },
            args
        );

        if (err)
        {
            throw LuteException{uv_strerror(err)};
        }
    }

    int resume() override
    {
        if (getRequest()->result != 0)
        {
            throw LuteException{uv_strerror(getRequest()->result)};
        }

        return 0;
    }

    void callback() override
    {
        schedule();
    }

private:
    UVFunction uv_fn;
    std::tuple<Args...> args;
};

class OpenFileOperation
    : public Task
    , public UVAsyncOperation<uv_fs_t>
{
public:
    OpenFileOperation(Runtime* runtime, lua_State* L, std::string path, int openFlags, int modeFlags)
        : Task{runtime, L}
        , UVAsyncOperation<uv_fs_t>{}
        , path(std::move(path))
        , openFlags(openFlags)
        , modeFlags(modeFlags)
    {
    }

    void start() override
    {
        int err = uv_fs_open(uv_default_loop(), getRequest(), path.c_str(), openFlags, modeFlags, uv_async_callback);

        if (err)
        {
            throw LuteException{std::string{"Error opening file: "} + uv_strerror(err)};
        }
    }

    int resume() override
    {
        int fd = getRequest()->result;

        if (fd < 0)
        {
            throw LuteException{std::string{"Error opening file: "} + uv_strerror(fd)};
        }

        lua_pushinteger(getThread(), fd);
        return 1;
    }

    void callback() override
    {
        schedule();
    }

private:
    std::string path;
    int openFlags;
    int modeFlags;
};

int open(lua_State* L)
{
    int nArgs = lua_gettop(L);
    const char* path = luaL_checkstring(L, 1);
    int openFlags = 0x0000;
    // When the number of arguments is less 2
    if (nArgs < 1)
    {
        luaL_errorL(L, "Error: no file supplied\n");
        return 0;
    }

    if (nArgs < 2)
    {
        openFlags = O_RDONLY;
    }

    const char* mode = luaL_checkstring(L, 2);
    int modeFlags = setFlags(mode, &openFlags);

    Runtime* runtime = getRuntime(L);

    runtime->addTask(std::make_unique<OpenFileOperation>(runtime, L, path, openFlags, modeFlags));

    return 0;
}

int close(lua_State* L)
{
    lua_settop(L, 1);
    FileHandle file = unpackFileHandle(L);

    Runtime* runtime = getRuntime(L);

    runtime->addTask(std::make_unique<SimpleFSOperation<uv_file>>(runtime, L, uv_fs_close, file.fileDescriptor));

    return lua_yield(L, 0);
}

class ReadOperation
    : public Task
    , public UVAsyncOperation<uv_fs_t>
{
public:
    constexpr static size_t BUFFER_SIZE = 1024;

    ReadOperation(Runtime* runtime, lua_State* L, int fd)
        : Task{runtime, L}
        , UVAsyncOperation<uv_fs_t>{}
        , fd{fd}
    {
    }

    void start() override
    {
        int err = uv_fs_read(uv_default_loop(), getRequest(), fd, &buf, 1, -1, uv_async_callback);

        if (err)
        {
            throw LuteException{uv_strerror(err)};
        }
    }

    int resume() override
    {
        if (getRequest()->result != 0)
        {
            throw LuteException{uv_strerror(getRequest()->result)};
        }

        lua_pushlstring(getThread(), stringBuffer.data(), stringBuffer.size());

        return 1;
    }

    void callback() override
    {
        size_t bytesRead = getRequest()->result;

        if (bytesRead < 0)
        {
            schedule();
            return;
        }

        if (bytesRead == 0)
        {
            schedule();
            return;
        }

        stringBuffer.append(buffer.data(), bytesRead);

        start();
    }

private:
    int fd;
    std::string stringBuffer;
    std::array<char, BUFFER_SIZE> buffer{};
    uv_buf_t buf = uv_buf_init(buffer.data(), BUFFER_SIZE);
};

int read(lua_State* L)
{
    FileHandle file = unpackFileHandle(L);

    Runtime* runtime = getRuntime(L);

    runtime->addTask(std::make_unique<ReadOperation>(runtime, L, file.fileDescriptor));

    return lua_yield(L, 0);
}

class WriteOperation
    : public Task
    , public UVAsyncOperation<uv_fs_t>
{
public:
    constexpr static size_t BUFFER_SIZE = 1024;

    WriteOperation(Runtime* runtime, lua_State* L, int fd, std::string data)
        : Task{runtime, L}
        , UVAsyncOperation<uv_fs_t>{}
        , fd{fd}
        , bytesRemaining{data.length()}
        , data{std::move(data)}
        , buf{uv_buf_init(this->data.data(), this->data.length())}
    {
    }

    void start() override
    {
        int err = uv_fs_write(uv_default_loop(), getRequest(), fd, &buf, 1, -1, uv_async_callback);

        if (err)
        {
            throw LuteException{uv_strerror(err)};
        }
    }

    int resume() override
    {
        if (getRequest()->result < 0)
        {
            throw LuteException{uv_strerror(getRequest()->result)};
        }

        return 0;
    }

    void callback() override
    {
        size_t bytesWritten = getRequest()->result;

        if (bytesWritten < 0)
        {
            throw LuteException{uv_strerror(bytesWritten)};
        }

        bytesRemaining -= bytesWritten;

        if (bytesRemaining == 0)
        {
            schedule();
            return;
        }

        start();
    }

private:
    int fd;
    size_t bytesRemaining;
    std::string data;
    uv_buf_t buf;
};

int write(lua_State* L)
{
    Runtime* runtime = getRuntime(L);
    FileHandle file = unpackFileHandle(L);

    runtime->addTask(std::make_unique<WriteOperation>(runtime, L, file.fileDescriptor, luaL_checkstring(L, 2)));

    return lua_yield(L, 0);
}



int fs_remove(lua_State* L)
{
    Runtime* runtime = getRuntime(L);

    runtime->addTask(std::make_unique<SimpleFSOperation<const char*>>(runtime, L, uv_fs_unlink, luaL_checkstring(L, 1)));

    return lua_yield(L, 0);
}

int fs_rmdir(lua_State* L)
{
    Runtime* runtime = getRuntime(L);

    runtime->addTask(std::make_unique<SimpleFSOperation<const char*>>(runtime, L, uv_fs_rmdir, luaL_checkstring(L, 1)));

    return lua_yield(L, 0);
}

int fs_mkdir(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    int mode = luaL_optinteger(L, 2, 0777);

    Runtime* runtime = getRuntime(L);

    runtime->addTask(std::make_unique<SimpleFSOperation<const char*, int>>(runtime, L, uv_fs_mkdir, path, mode));

    return lua_yield(L, 0);
}

int fs_copy(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    const char* dest = luaL_checkstring(L, 2);

    Runtime* runtime = getRuntime(L);

    runtime->addTask(std::make_unique<SimpleFSOperation<const char*, const char*, int>>(runtime, L, uv_fs_copyfile, path, dest, 0));

    return lua_yield(L, 0);
}

int fs_link(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    const char* dest = luaL_checkstring(L, 2);

    Runtime* runtime = getRuntime(L);

    runtime->addTask(std::make_unique<SimpleFSOperation<const char*, const char*>>(runtime, L, uv_fs_link, path, dest));

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

    Runtime* runtime = getRuntime(L);

    runtime->addTask(std::make_unique<SimpleFSOperation<const char*, const char*, int>>(runtime, L, uv_fs_symlink, path, dest, req->flags));

    return lua_yield(L, 0);
}



class StatFileOperation
    : public Task
    , public UVAsyncOperation<uv_fs_t>
{
public:
    StatFileOperation(Runtime* runtime, lua_State* L, std::string path)
        : Task{runtime, L}
        , UVAsyncOperation<uv_fs_t>{}
        , path(std::move(path))
    {
    }

    void start() override
    {
        int err = uv_fs_stat(uv_default_loop(), getRequest(), path.c_str(), uv_async_callback);

        if (err)
        {
            throw LuteException{std::string{"Error stating file: "} + uv_strerror(err)};
        }
    }

    int resume() override
    {
        auto& stat = getRequest()->statbuf;

        lua_createtable(getThread(), 0, 6);

        auto type = fileModeToType(stat.st_mode);
        lua_pushstring(getThread(), type);
        lua_setfield(getThread(), -2, "type");

        lua_pushnumber(getThread(), static_cast<double>(stat.st_size));
        lua_setfield(getThread(), -2, "size");

        createDurationFromTimespec32(getThread(), stat.st_birthtim);
        lua_setfield(getThread(), -2, "created_at");

        createDurationFromTimespec32(getThread(), stat.st_atim);
        lua_setfield(getThread(), -2, "accessed_at");

        createDurationFromTimespec32(getThread(), stat.st_mtim);
        lua_setfield(getThread(), -2, "modified_at");

        lua_createtable(getThread(), 0, 2);

        bool canAnyWrite = stat.st_mode & 0222;
        lua_pushboolean(getThread(), !canAnyWrite);
        lua_setfield(getThread(), -2, "readonly");

        lua_setfield(getThread(), -2, "permissions");

        return 1;
    }

    void callback() override
    {
        schedule();
    }

private:
    std::string path;
};

int fs_stat(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    Runtime* runtime = getRuntime(L);

    runtime->addTask(std::make_unique<StatFileOperation>(runtime, L, path));

    return lua_yield(L, 0);
}

class ResumeNewThread : public Task
{
public:
    ResumeNewThread(Runtime* runtime, lua_State* L, std::function<int(lua_State*)> func)
        : Task{runtime, L}
        , func{std::move(func)}
    {
    }

    void start() override
    {
        schedule();
    }

    int resume() override
    {
        return func(getThread());
    }

private:
    std::function<int(lua_State*)> func;
};

class WatcherTask : public Task
{
public:
    WatcherTask(Runtime* runtime, lua_State* L, std::string path, std::unique_ptr<Ref> callbackReference)
        : Task{runtime, L}
        , path{std::move(path)}
        , callbackReference{std::move(callbackReference)}
    {
        request.data = this;
    }

    void start() override
    {
        int err = uv_fs_event_init(uv_default_loop(), &request);

        if (err)
        {
            throw LuteException{uv_strerror(err)};
        }

        err = uv_fs_event_start(&request, uv_async_callback, path.c_str(), 0);

        if (err)
        {
            throw LuteException{uv_strerror(err)};
        }
    }

    // ended
    int resume() override
    {
        return 0;
    }

    // stops the watcher
    void stop()
    {
        uv_fs_event_stop(&request);
    }

private:
    void callback(const char* filename, int events, int status)
    {
        getRuntime()->addTask(std::make_unique<ResumeNewThread>(
            getRuntime(),
            getRuntime()->newThread(),
            [=, watcher = this, filename = std::move(filename)](lua_State* L)
            {
                // the function to the back of the stack, omit from nret
                watcher->callbackReference->push(L);

                // filename
                lua_pushstring(L, filename);

                // events
                lua_createtable(L, 0, 2);

                if ((events & UV_RENAME) == UV_RENAME)
                {
                    lua_pushboolean(L, true);
                    lua_setfield(L, -2, "rename");
                }
                else
                {
                    lua_pushboolean(L, false);
                    lua_setfield(L, -2, "rename");
                }

                if ((events & UV_CHANGE) == UV_CHANGE)
                {
                    lua_pushboolean(L, true);
                    lua_setfield(L, -2, "change");
                }
                else
                {
                    lua_pushboolean(L, false);
                    lua_setfield(L, -2, "change");
                }

                return 2;
            }
        ));

        // interrupt
        uv_stop(uv_default_loop());
    }

    static void uv_async_callback(uv_fs_event_t* handle, const char* filename, int events, int status)
    {
        auto* task = static_cast<WatcherTask*>(handle->data);
        task->callback(filename, events, status);
    }

    std::string path;
    std::unique_ptr<Ref> callbackReference;
    uv_fs_event_t request;
};

int fs_watch(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);

    Runtime* runtime = getRuntime(L);

    auto watch = std::make_unique<WatcherTask>(runtime, L, path, std::make_unique<Ref>(L, 2));

    WatcherTask* taskPtr = dynamic_cast<WatcherTask*>(runtime->addTask(std::move(watch)));

    auto* handle = static_cast<WatcherTask**>(lua_newuserdatataggedwithmetatable(L, sizeof(WatcherTask*), kWatchHandleTag));

    (*handle) = taskPtr;

    return 1;
}

class FileExistsOperation : public StatFileOperation
{
public:
    FileExistsOperation(Runtime* runtime, lua_State* L, std::string path)
        : StatFileOperation{runtime, L, std::move(path)}
    {
    }

    int resume() override
    {
        lua_pushboolean(getThread(), getRequest()->result != UV_ENOENT);

        return 1;
    }
};

int fs_exists(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    getRuntime(L)->addTask(std::make_unique<FileExistsOperation>(getRuntime(L), L, path));

    return lua_yield(L, 0);
}

class FileTypeOperation : public StatFileOperation
{
public:
    FileTypeOperation(Runtime* runtime, lua_State* L, std::string path)
        : StatFileOperation{runtime, L, std::move(path)}
    {
    }

    int resume() override
    {
        auto type = fileModeToType(getRequest()->statbuf.st_mode);
        lua_pushstring(getThread(), type);

        return 1;
    }
};

int type(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    getRuntime(L)->addTask(std::make_unique<FileTypeOperation>(getRuntime(L), L, path));

    return lua_yield(L, 0);
}


class ListDirectoryOperation
    : public Task
    , public UVAsyncOperation<uv_fs_t>
{
public:
    ListDirectoryOperation(Runtime* runtime, lua_State* L, std::string path)
        : Task{runtime, L}
        , UVAsyncOperation<uv_fs_t>{}
        , path(std::move(path))
    {
    }

    void start() override
    {
        int err = uv_fs_scandir(uv_default_loop(), getRequest(), path.c_str(), 0, uv_async_callback);

        if (err)
        {
            throw LuteException{std::string{"Error listing directory: "} + uv_strerror(err)};
        }
    }

    int resume() override
    {
        lua_State* L = getThread();

        lua_createtable(L, 1, 0);

        uv_dirent_t dir;
        int i = 0;
        int err = 0;
        while ((err = uv_fs_scandir_next(getRequest(), &dir)) >= 0)
        {
            lua_pushinteger(L, ++i);

            lua_createtable(L, 0, 2);

            lua_pushstring(L, dir.name);
            lua_setfield(L, -2, "name");

            lua_pushstring(L, UV_DIRENT_TYPES[dir.type]);
            lua_setfield(L, -2, "type");

            lua_settable(L, -3);
        }

        if (err != UV_EOF)
            throw LuteException{uv_strerror(err)};

        return 1;
    }

    void callback() override
    {
        schedule();
    }

private:
    std::string path;
};

int listdir(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    getRuntime(L)->addTask(std::make_unique<ListDirectoryOperation>(getRuntime(L), L, path));

    return lua_yield(L, 0);
}

class AsyncReadFile : public OpenFileOperation
{
public:
    AsyncReadFile(Runtime* runtime, lua_State* L, std::string path, int openFlags)
        : OpenFileOperation{runtime, L, std::move(path), openFlags, 0}
    {
    }

    int resume() override
    {
        // cannot be resumed
        LUAU_UNREACHABLE();

        return 0;
    }

    void callback() override
    {
        int fd = getRequest()->result;

        if (fd < 0)
        {
            throw LuteException{uv_strerror(fd)};
        }

        getRuntime()->addTask(std::make_unique<ReadOperation>(getRuntime(), getThread(), fd));

        cancel();
    }
};

int readfile(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    Runtime* runtime = getRuntime(L);

    runtime->addTask(std::make_unique<AsyncReadFile>(runtime, L, path, O_RDONLY));
    return lua_yield(L, 0);
}

int readasync(lua_State* L)
{
    return readfile(L);
}

int readfiletostring(lua_State* L)
{
    return readfile(L);
}

class AsyncWriteFile : public OpenFileOperation
{
public:
    AsyncWriteFile(Runtime* runtime, lua_State* L, std::string path, std::string data, bool append = false)
        : OpenFileOperation{runtime, L, std::move(path), (O_WRONLY | O_CREAT) | (append ? O_APPEND : O_TRUNC), 0}
        , data{std::move(data)}
    {
    }

    int resume() override
    {
        // cannot be resumed

        LUAU_UNREACHABLE();

        return 0;
    }

    void callback() override
    {
        int fd = getRequest()->result;

        if (fd < 0)
        {
            throw LuteException{uv_strerror(fd)};
        }

        getRuntime()->addTask(std::make_unique<WriteOperation>(getRuntime(), getThread(), fd, std::move(data)));

        cancel();
    }

private:
    std::string data;
};

int writestringtofile(lua_State* L)
{
    Runtime* runtime = getRuntime(L);

    runtime->addTask(std::make_unique<AsyncWriteFile>(runtime, L, luaL_checkstring(L, 1), luaL_checkstring(L, 2), true));

    return lua_yield(L, 0);
}

int writefile(lua_State* L)
{
    Runtime* runtime = getRuntime(L);

    runtime->addTask(std::make_unique<AsyncWriteFile>(runtime, L, luaL_checkstring(L, 1), luaL_checkstring(L, 2)));

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
                lua_pushcfunction(
                    L,
                    [](lua_State* L) -> int
                    {
                        auto* handle = static_cast<fs::WatcherTask**>(lua_touserdatatagged(L, 1, kWatchHandleTag));

                        if (!handle)
                        {
                            return 0;
                        }

                        (*handle)->stop();

                        return 0;
                    },
                    "WatchHandle.close"
                );

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
            // we dont call a dtor on this because its managed by the Runtime, call the cancel method

            auto* handle = static_cast<fs::WatcherTask**>(ud);

            (*handle)->resume();
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
