#include "lute/fs.h"

#include "lua.h"
#include "lualib.h"
#include "uv.h"

#include "lute/runtime.h"
#include "lute/userdatas.h"

#include <cstdio>
#include <cstring>
#ifdef _WIN32
#include <direct.h>
#endif
#include <fcntl.h>
#include <filesystem>
#include <map>
#include <memory>
#include <optional>
#include <sys/stat.h>
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

int close(lua_State* L)
{
    lua_settop(L, 1);
    FileHandle file = unpackFileHandle(L);

    uv_fs_t closeReq;
    uv_fs_close(uv_default_loop(), &closeReq, file.fileDescriptor, nullptr);
    return 0;
}

static char readBuffer[1024];
int read(lua_State* L)
{
    memset(readBuffer, 0, sizeof(readBuffer));
    // discard any extra arguments passed in
    lua_settop(L, 1);
    FileHandle file = unpackFileHandle(L);

    int numBytesRead = 0;
    uv_fs_t readReq;
    uv_buf_t iov = uv_buf_init(readBuffer, sizeof(readBuffer));
    // Output data
    std::vector<char> resultData;
    do
    {
        uv_fs_read(uv_default_loop(), &readReq, file.fileDescriptor, &iov, 1, -1, nullptr);

        numBytesRead = readReq.result;

        if (numBytesRead < 0)
        {
            luaL_errorL(L, "Error reading: %s. Closing file.\n", uv_err_name(numBytesRead));
            memset(readBuffer, 0, sizeof(readBuffer));
            return 0;
        }

        for (int i = 0; i < numBytesRead; i++)
            resultData.push_back(readBuffer[i]);

    } while (numBytesRead > 0);

    lua_pushlstring(L, resultData.data(), resultData.size());

    // Clean up the scratch space
    memset(readBuffer, 0, sizeof(readBuffer));
    return 1;
}

int write(lua_State* L)
{
    char writeBuffer[4096];

    // Reset the write buffer
    int wbSize = sizeof(writeBuffer);
    memset(writeBuffer, 0, sizeof(writeBuffer));
    FileHandle file = unpackFileHandle(L);
    const char* stringToWrite = luaL_checkstring(L, 2);

    // Set up the buffer to write
    int numBytesLeftToWrite = strlen(stringToWrite);
    int offset = 0;
    do
    {
        // copy stringToWrite[0], numBytesLeftToWrite into write buffer

        int sizeToWrite = std::min(wbSize, numBytesLeftToWrite);
        memcpy(writeBuffer, stringToWrite + offset, sizeToWrite);
        uv_buf_t iov = uv_buf_init(writeBuffer, sizeToWrite);

        uv_fs_t writeReq;
        int bytesWritten = 0;
        uv_fs_write(uv_default_loop(), &writeReq, file.fileDescriptor, &iov, 1, -1, nullptr);
        bytesWritten = writeReq.result;

        if (bytesWritten < 0)
        {
            // Error case.
            luaL_errorHandle(L, file);
            memset(writeBuffer, 0, sizeof(writeBuffer));
            return 0;
        }


        offset += bytesWritten;
        numBytesLeftToWrite -= bytesWritten;
    } while (numBytesLeftToWrite > 0);

    return 0;
}
// Returns 0 on error, 1 otherwise
std::optional<FileHandle> openHelper(lua_State* L, const char* path, const char* mode, int* openFlags)
{
    std::optional<int> modeFlags = setFlags(mode, openFlags);
    if (!modeFlags)
        return std::nullopt;

    uv_fs_t openReq;
    int errcode = uv_fs_open(uv_default_loop(), &openReq, path, *openFlags, *modeFlags, nullptr);
    if (openReq.result < 0)
    {
        luaL_errorL(L, "Error opening file %s\n", path);
        return std::nullopt;
    }

    return FileHandle{openReq.result, errcode};
}

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
    if (std::optional<FileHandle> result = openHelper(L, path, mode, &openFlags))
    {
        createFileHandle(L, *result);
        return 1;
    }

    return 0;
}

void cleanup(char* buffer, int size, const FileHandle& handle)
{
    memset(buffer, 0, size);
    uv_fs_t closeReq;
    uv_fs_close(uv_default_loop(), &closeReq, handle.fileDescriptor, nullptr);
}

int fs_remove(lua_State* L)
{
    uv_fs_t unlink_req;
    int err = uv_fs_unlink(uv_default_loop(), &unlink_req, luaL_checkstring(L, 1), nullptr);

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

    if (err)
        luaL_errorL(L, "%s", uv_strerror(err));

    return 0;
}

int fs_rmdir(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    uv_fs_t rmdir_req;
    int err = uv_fs_rmdir(uv_default_loop(), &rmdir_req, path, nullptr);

    if (err)
        luaL_errorL(L, "%s", uv_strerror(err));

    return 0;
}

static void defaultCallback(uv_fs_t* req)
{
    auto* request_state = static_cast<ResumeToken*>(req->data);

    if (req->result)
    {
        request_state->get()->fail(uv_strerror(req->result));
        uv_fs_req_cleanup(req);
        delete req;
        return;
    }

    request_state->get()->complete(
        [req](lua_State* L)
        {
            uv_fs_req_cleanup(req);

            delete req;

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

    int err = uv_fs_event_stop(&handle->handle);
    if (err)
    {
        luaL_errorL(L, "Error stopping fs event: %s", uv_strerror(err));
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
                    lua_pushstring(L, filename.c_str());

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

    int err = uv_fs_stat(
        uv_default_loop(),
        req,
        path,
        [](uv_fs_t* req)
        {
            auto* request_state = static_cast<ResumeToken*>(req->data);

            request_state->get()->complete(
                [req](lua_State* L)
                {
                    if (req->result == UV_ENOENT)
                    {
                        lua_pushboolean(L, false); // does not exist
                    }
                    else
                    {
                        lua_pushboolean(L, true);
                    }

                    uv_fs_req_cleanup(req);

                    delete req;

                    return 1;
                }
            );
        }
    );

    if (err)
    {
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
        luaL_errorL(L, "%s", uv_strerror(err));

    if (S_ISDIR(req.statbuf.st_mode))
    {
        lua_pushstring(L, UV_TYPENAME_DIR);
    }
    else if (S_ISREG(req.statbuf.st_mode))
    {
        lua_pushstring(L, UV_TYPENAME_FILE);
    }
    else if (S_ISCHR(req.statbuf.st_mode))
    {
        lua_pushstring(L, UV_TYPENAME_CHAR);
    }
    else if (S_ISLNK(req.statbuf.st_mode))
    {
        lua_pushstring(L, UV_TYPENAME_LINK);
    }
#ifdef S_ISBLK
    else if (S_ISBLK(req.statbuf.st_mode))
    {
        lua_pushstring(L, UV_TYPENAME_BLOCK);
    }
#endif
#ifdef S_ISFIFO
    else if (S_ISFIFO(req.statbuf.st_mode))
    {
        lua_pushstring(L, UV_TYPENAME_FIFO);
    }
#endif
#ifdef S_ISSOCK
    else if (S_ISSOCK(req.statbuf.st_mode))
    {
        lua_pushstring(L, UV_TYPENAME_SOCKET);
    }
#endif
    else
    {
        lua_pushstring(L, UV_TYPENAME_UNKNOWN);
    }


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

                    delete req;

                    if (err != UV_EOF)
                        luaL_errorL(L, "%s", uv_strerror(err));

                    return 1;
                }
            );
        }
    );

    if (err)
        luaL_errorL(L, "%s", uv_strerror(err));

    return lua_yield(L, 0);
}

int readfiletostring(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);
    const char openMode[] = "r";
    int openFlags = 0x0000;
    std::optional<FileHandle> handle = openHelper(L, path, openMode, &openFlags);
    if (!handle)
    {
        luaL_errorL(L, "Error opening file for reading at %s\n", path);
        return 0;
    }

    memset(readBuffer, 0, sizeof(readBuffer));
    // discard any extra arguments passed in
    lua_settop(L, 1);

    int numBytesRead = 0;
    uv_fs_t readReq;
    uv_buf_t iov = uv_buf_init(readBuffer, sizeof(readBuffer));
    // Output data
    std::vector<char> resultData;
    do
    {
        uv_fs_read(uv_default_loop(), &readReq, handle->fileDescriptor, &iov, 1, -1, nullptr);

        numBytesRead = readReq.result;

        if (numBytesRead < 0)
        {
            luaL_errorL(L, "Error reading: %s. Closing file.\n", uv_err_name(numBytesRead));
            cleanup(readBuffer, sizeof(readBuffer), *handle);
            return 0;
        }

        for (int i = 0; i < numBytesRead; i++)
            resultData.push_back(readBuffer[i]);

    } while (numBytesRead > 0);

    lua_pushlstring(L, resultData.data(), resultData.size());

    // Clean up the scratch space
    cleanup(readBuffer, sizeof(readBuffer), *handle);
    return 1;
}

int writestringtofile(lua_State* L)
{
    char writeBuffer[4096];

    const char* path = luaL_checkstring(L, 1);
    const char openMode[] = "w+";
    int openFlags = 0x0000;
    std::optional<FileHandle> handle = openHelper(L, path, openMode, &openFlags);
    if (!handle)
    {
        luaL_errorL(L, "Error opening file for reading at %s\n", path);
        return 0;
    }

    int wbSize = sizeof(writeBuffer);
    memset(writeBuffer, 0, sizeof(writeBuffer));
    const char* stringToWrite = luaL_checkstring(L, 2);

    // Set up the buffer to write
    int numBytesLeftToWrite = strlen(stringToWrite);
    int offset = 0;
    uv_buf_t iov;
    do
    {
        // copy stringToWrite[0], numBytesLeftToWrite into write buffer

        int sizeToWrite = std::min(wbSize, numBytesLeftToWrite);
        memcpy(writeBuffer, stringToWrite + offset, sizeToWrite);
        iov = uv_buf_init(writeBuffer, sizeToWrite);

        uv_fs_t writeReq;
        int bytesWritten = 0;
        uv_fs_write(uv_default_loop(), &writeReq, handle->fileDescriptor, &iov, 1, -1, nullptr);
        bytesWritten = writeReq.result;

        if (bytesWritten < 0)
        {
            // Error case.
            luaL_errorHandle(L, *handle);
            cleanup(writeBuffer, sizeof(writeBuffer), *handle);
            return 0;
        }


        offset += bytesWritten;
        numBytesLeftToWrite -= bytesWritten;
    } while (numBytesLeftToWrite > 0);

    cleanup(writeBuffer, sizeof(writeBuffer), *handle);
    return 0;
}

struct ResumeCaptureInformation
{
    explicit ResumeCaptureInformation(lua_State* L)
        : token(getResumeToken(L))
    {
    }

    ResumeToken token = nullptr;
};

uv_fs_t* createRequest(lua_State* L)
{
    uv_fs_t* req = new uv_fs_t();
    req->data = new ResumeCaptureInformation(L);
    return req;
}

ResumeCaptureInformation* getResumeInformation(uv_fs_t* req)
{
    return reinterpret_cast<ResumeCaptureInformation*>(req->data);
}

int readasync(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    uv_fs_t* openReq = createRequest(L);
    uv_fs_open(
        uv_default_loop(),
        openReq,
        path,
        O_RDONLY,
        0,
        [](uv_fs_t* req)
        {
            ResumeCaptureInformation* info = getResumeInformation(req);
            int fd = req->result;

            if (fd < 0)
            {
                info->token->fail("Error opening file");
                uv_fs_t closeReq;
                uv_fs_close(uv_default_loop(), &closeReq, fd, nullptr);
                uv_fs_req_cleanup(req);
                delete (ResumeCaptureInformation*)req->data;
                delete req;
                return;
            }

            // Allocate the destination buffer for reading
            char readBuffer[1024];
            memset(readBuffer, 0, sizeof(readBuffer));
            uv_buf_t iov = uv_buf_init(readBuffer, sizeof(readBuffer));
            // Read data
            int numBytesRead = 0;
            uv_fs_t readReq;
            // Output data
            std::vector<char> resultData;

            do
            {
                uv_fs_read(uv_default_loop(), &readReq, fd, &iov, 1, -1, nullptr);
                numBytesRead = readReq.result;

                if (numBytesRead < 0)
                {
                    uv_fs_t closeReq;
                    uv_fs_close(uv_default_loop(), &closeReq, fd, nullptr);
                    // Schedule error;
                    // Also, we should free the original request. We don't have to do this for the read req since it's sycnrhonous
                    info->token->fail("Error reading file");
                    uv_fs_req_cleanup(req);
                    delete (ResumeCaptureInformation*)req->data;
                    delete req;
                    return;
                }

                for (int i = 0; i < numBytesRead; i++)
                    resultData.push_back(readBuffer[i]);

            } while (numBytesRead > 0);

            // Push the result buffer onto the stack
            info->token->complete(
                [data = std::move(resultData)](lua_State* L)
                {
                    lua_pushlstring(L, data.data(), data.size());
                    return 1;
                }
            );

            uv_fs_t closeReq;
            uv_fs_close(uv_default_loop(), &closeReq, fd, nullptr);
            // free the read buffer as well as the resume information and the request
            delete (ResumeCaptureInformation*)req->data;
            delete req;
            return;
        }
    );

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
            auto* handle = static_cast<fs::WatchHandle*>(ud);

            handle->~WatchHandle();
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
