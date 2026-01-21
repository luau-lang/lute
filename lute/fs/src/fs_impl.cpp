#include "fs_impl.h"

#include "lute/fileutils.h"
#include "lute/time.h"
#include "lute/UVRequest.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#ifdef _WIN32
#include <direct.h>
#else
#include <unistd.h>
#endif

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

constexpr size_t kChunkIOSize = 4096;

namespace fs
{

using FSRequest = uvutils::UVRequest<uv_fs_t>;

struct FSRead : FSRequest
{
    FSRead(lua_State* L, UVFile* file)
        : FSRequest(L)
        , file(file)
    {
        chunk.resize(kChunkIOSize);
        iov = uv_buf_init(chunk.data(), chunk.size());
        buffer.reserve(kChunkIOSize);
    }

    static void readCallback(uv_fs_t* req);

    UVFile* file = nullptr;
    std::vector<char> buffer;
    std::vector<char> chunk;
    uv_buf_t iov;
};

struct FSWrite : FSRequest
{
    FSWrite(lua_State* L, UVFile* file, const char* buf, size_t len)
        : FSRequest(L)
        , file(file)
        , toWrite(buf, buf + len)
        , offset(0)
    {
        chunk.resize(kChunkIOSize);
    }

    static void writeCallback(uv_fs_t* req);

    UVFile* file = nullptr;
    std::vector<char> chunk;
    uv_buf_t iov;
    std::vector<char> toWrite;
    size_t offset = 0;
};

struct FSClose : FSRequest
{
    FSClose(lua_State* L, UVFile* file)
        : FSRequest(L)
        , file(file)
    {
    }

    ~FSClose()
    {
        delete file;
    }

    UVFile* file = nullptr;
};

struct FSPathPairRequest : FSRequest
{
    FSPathPairRequest(lua_State* L, const char* src, const char* dest)
        : FSRequest(L)
        , src(src)
        , dest(dest)
    {
    }

    const std::string src;
    const std::string dest;
};

int open_impl(lua_State* L, const char* path, int flags, int mode)
{
    uvutils::ScopedUVRequest<FSRequest> req(L);
    uv_fs_open(
        uv_default_loop(),
        &req->req,
        path,
        flags,
        mode,
        [](uv_fs_t* req)
        {
            auto r = uvutils::retake<FSRequest>(req);
            auto result = req->result;
            if (result < 0)
            {
                r->fail("Error opening file %s: %s", req->path, uv_strerror(result));
                return;
            }

            r->succeed(
                [result](lua_State* L)
                {
                    auto* file = new UVFile();
                    file->fd = result;
                    lua_pushlightuserdata(L, file);
                    return 1;
                }
            );
        }
    );

    return lua_yield(L, 0);
}

void FSRead::readCallback(uv_fs_t* req)
{
    auto r = uvutils::retake<FSRead>(req);
    auto bytesRead = req->result;

    if (bytesRead < 0)
    {
        r->fail("Error reading file: %s", uv_strerror(bytesRead));
        return;
    }

    if (bytesRead == 0)
    {
        r->succeed(
            [buffer = std::move(r->buffer)](lua_State* L)
            {
                lua_pushlstring(L, buffer.data(), buffer.size());
                return 1;
            }
        );
        return;
    }

    // Append the read data to our buffer
    r->buffer.insert(r->buffer.end(), r->chunk.begin(), r->chunk.begin() + bytesRead);

    // It's possible that the next read call will read fewer than chunk.size() bytes
    // In this case, the chunk buffer might still retain some data from this read. Just to be safe, zero it out
    std::fill(r->chunk.begin(), r->chunk.end(), 0);

    uvutils::ScopedUVRequest<FSRead> scopedReq{std::move(r)};
    uv_fs_read(uv_default_loop(), &scopedReq->req, scopedReq->file->fd.value(), &scopedReq->iov, 1, -1, FSRead::readCallback);
}

void FSWrite::writeCallback(uv_fs_t* req)
{
    auto w = uvutils::retake<FSWrite>(req);
    auto bytesWritten = req->result;
    if (bytesWritten < 0)
    {
        w->fail("Error writing file: %s", uv_strerror(bytesWritten));
        return;
    }

    w->offset += bytesWritten;
    if (w->offset == w->toWrite.size())
    {
        w->succeed(
            [](lua_State* L)
            {
                return 0;
            }
        );

        return;
    }

    // Copy next chunk to write
    size_t remaining = w->toWrite.size() - w->offset;
    size_t chunkSize = std::min(remaining, w->chunk.size());
    std::copy(w->toWrite.begin() + w->offset, w->toWrite.begin() + w->offset + chunkSize, w->chunk.begin());
    w->iov = uv_buf_init(w->chunk.data(), chunkSize);

    uvutils::ScopedUVRequest<FSWrite> scopedReq{std::move(w)};
    uv_fs_write(uv_default_loop(), &scopedReq->req, scopedReq->file->fd.value(), &scopedReq->iov, 1, -1, FSWrite::writeCallback);
}

int read_impl(lua_State* L, UVFile* handle)
{
    if (!handle->fd.has_value())
    {
        luaL_errorL(L, "File handle is closed");
    }

    uvutils::ScopedUVRequest<FSRead> req{L, handle};
    uv_fs_read(uv_default_loop(), &req->req, handle->fd.value(), &req->iov, 1, -1, FSRead::readCallback);
    // Automatically releases when req goes out of scope
    return lua_yield(L, 0);
}

int write_impl(lua_State* L, UVFile* handle, const char* toWrite, size_t numBytes)
{
    if (!handle->fd.has_value())
    {
        luaL_errorL(L, "File handle is closed");
    }

    uvutils::ScopedUVRequest<FSWrite> req{L, handle, toWrite, numBytes};

    // Copy first chunk to write
    size_t chunkSize = std::min(numBytes, req->chunk.size());
    std::copy(req->toWrite.begin(), req->toWrite.begin() + chunkSize, req->chunk.begin());
    req->iov = uv_buf_init(req->chunk.data(), chunkSize);

    uv_fs_write(uv_default_loop(), &req->req, handle->fd.value(), &req->iov, 1, -1, FSWrite::writeCallback);

    return lua_yield(L, 0);
}

int close_impl(lua_State* L, UVFile* handle)
{
    if (!handle->fd.has_value())
    {
        luaL_errorL(L, "File handle is already closed");
    }

    uvutils::ScopedUVRequest<FSClose> req{L, handle};
    uv_fs_close(
        uv_default_loop(),
        &req->req,
        handle->fd.value(),
        [](uv_fs_t* req)
        {
            auto r = uvutils::retake<FSClose>(req);
            auto result = req->result;

            if (result < 0)
            {
                r->fail("Error closing file: %s", uv_strerror(result));
                return;
            }

            r->succeed(
                [](lua_State* L)
                {
                    return 0;
                }
            );
        }
    );

    return lua_yield(L, 0);
}

int remove_impl(lua_State* L, const char* path)
{
    uvutils::ScopedUVRequest<FSRequest> req(L);
    uv_fs_unlink(
        uv_default_loop(),
        &req->req,
        path,
        [](uv_fs_t* req)
        {
            auto r = uvutils::retake<FSRequest>(req);
            auto result = req->result;
            if (result < 0)
            {
                r->fail("Error removing file %s: %s", req->path, uv_strerror(result));
                return;
            }

            r->succeed(
                [](lua_State* L)
                {
                    return 0;
                }
            );
        }
    );

    return lua_yield(L, 0);
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

static int createDurationFromTimespec32(lua_State* L, uv_timespec_t timespec)
{
    uv_timespec64_t extended{static_cast<int64_t>(timespec.tv_sec), static_cast<int32_t>(timespec.tv_nsec)};
    return createDurationFromTimespec(L, extended);
}

int stat_impl(lua_State* L, const char* path)
{
    uvutils::ScopedUVRequest<FSRequest> req(L);
    uv_fs_stat(
        uv_default_loop(),
        &req->req,
        path,
        [](uv_fs_t* req)
        {
            auto r = uvutils::retake<FSRequest>(req);
            auto result = req->result;

            if (result < 0)
            {
                r->fail("Error getting metadata of file %s: %s", req->path, uv_strerror(result));
                return;
            }

            r->succeed(
                [stat = req->statbuf](lua_State* L)
                {
                    lua_createtable(L, 0, 6);

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

                    return 1;
                }
            );
        }
    );

    return lua_yield(L, 0);
}

int exists_impl(lua_State* L, const char* path)
{
    uvutils::ScopedUVRequest<FSRequest> req(L);
    uv_fs_access(
        uv_default_loop(),
        &req->req,
        path,
        F_OK,
        [](uv_fs_t* req)
        {
            auto r = uvutils::retake<FSRequest>(req);
            auto result = req->result;

            if (result < 0 && result != UV_ENOENT)
            {
                r->fail("exists: Error checking existence of %s: %s", req->path, uv_strerror(result));
                return;
            }

            r->succeed(
                [exists = (result == 0)](lua_State* L)
                {
                    lua_pushboolean(L, exists);
                    return 1;
                }
            );
        }
    );

    return lua_yield(L, 0);
}

int type_impl(lua_State* L, const char* path)
{
    uvutils::ScopedUVRequest<FSRequest> req(L);
    uv_fs_stat(
        uv_default_loop(),
        &req->req,
        path,
        [](uv_fs_t* req)
        {
            auto r = uvutils::retake<FSRequest>(req);
            auto result = req->result;

            if (result < 0)
            {
                r->fail("Error getting type of file %s: %s", req->path, uv_strerror(result));
                return;
            }

            r->succeed(
                [stat = req->statbuf](lua_State* L)
                {
                    auto type = fileModeToType(stat.st_mode);
                    lua_pushstring(L, type);
                    return 1;
                }
            );
        }
    );

    return lua_yield(L, 0);
}

int link_impl(lua_State* L, const char* path, const char* dest)
{
    uvutils::ScopedUVRequest<FSPathPairRequest> req{L, path, dest};
    uv_fs_link(
        uv_default_loop(),
        &req->req,
        path,
        dest,
        [](uv_fs_t* req)
        {
            auto r = uvutils::retake<FSPathPairRequest>(req);
            auto result = req->result;

            if (result < 0)
            {
                r->fail("link: Error creating link from %s to %s: %s", r->src.c_str(), r->dest.c_str(), uv_strerror(result));
                return;
            }

            r->succeed(
                [](lua_State* L)
                {
                    return 0;
                }
            );
        }
    );

    return lua_yield(L, 0);
}

int symlink_impl(lua_State* L, const char* path, const char* dest)
{
    uvutils::ScopedUVRequest<FSPathPairRequest> req{L, path, dest};
    int flags = 0;
#if _WIN32
    flags = Lute::isDirectory(path) ? UV_FS_SYMLINK_DIR : 0;
#endif

    uv_fs_symlink(
        uv_default_loop(),
        &req->req,
        path,
        dest,
        flags,
        [](uv_fs_t* req)
        {
            auto r = uvutils::retake<FSPathPairRequest>(req);
            auto result = req->result;

            if (result < 0)
            {
                r->fail("symlink: Error creating symlink from %s to %s: %s", r->src.c_str(), r->dest.c_str(), uv_strerror(result));
                return;
            }

            r->succeed(
                [](lua_State* L)
                {
                    return 0;
                }
            );
        }
    );

    return lua_yield(L, 0);
}

int copy_impl(lua_State* L, const char* path, const char* dest)
{
    uvutils::ScopedUVRequest<FSPathPairRequest> req{L, path, dest};
    uv_fs_copyfile(
        uv_default_loop(),
        &req->req,
        path,
        dest,
        0,
        [](uv_fs_t* req)
        {
            auto r = uvutils::retake<FSPathPairRequest>(req);
            auto result = req->result;

            if (result < 0)
            {
                r->fail("copy: Error copying file from %s to %s: %s", r->src.c_str(), r->dest.c_str(), uv_strerror(result));
                return;
            }

            r->succeed(
                [](lua_State* L)
                {
                    return 0;
                }
            );
        }
    );

    return lua_yield(L, 0);
}

int mkdir_impl(lua_State* L, const char* path, int mode)
{
    uvutils::ScopedUVRequest<FSRequest> req(L);
    uv_fs_mkdir(
        uv_default_loop(),
        &req->req,
        path,
        mode,
        [](uv_fs_t* req)
        {
            auto r = uvutils::retake<FSRequest>(req);
            auto result = req->result;
            if (result < 0)
            {
                r->fail("Error creating directory %s: %s", req->path, uv_strerror(result));
                return;
            }

            r->succeed(
                [](lua_State* L)
                {
                    return 0;
                }
            );
        }
    );

    return lua_yield(L, 0);
}


int rmdir_impl(lua_State* L, const char* path)
{
    uvutils::ScopedUVRequest<FSRequest> req(L);
    uv_fs_rmdir(
        uv_default_loop(),
        &req->req,
        path,
        [](uv_fs_t* req)
        {
            auto r = uvutils::retake<FSRequest>(req);
            auto result = req->result;
            if (result < 0)
            {
                r->fail("Error removing directory %s: %s", req->path, uv_strerror(result));
                return;
            }

            r->succeed(
                [](lua_State* L)
                {
                    return 0;
                }
            );
        }
    );

    return lua_yield(L, 0);
}


int listdir_impl(lua_State* L, const char* path)
{
    uvutils::ScopedUVRequest<FSRequest> req(L);
    uv_fs_scandir(
        uv_default_loop(),
        &req->req,
        path,
        0,
        [](uv_fs_t* req)
        {
            auto r = uvutils::retake<FSRequest>(req);
            auto result = req->result;
            if (result < 0)
            {
                r->fail("listdir: Error listing directory %s (%s)", req->path, uv_strerror(result));
                return;
            }

            std::vector<std::pair<std::string, uv_dirent_type_t>> entries;
            uv_dirent_t dirent;
            int err = 0;
            while ((err = uv_fs_scandir_next(req, &dirent)) >= 0)
            {
                entries.emplace_back(dirent.name, dirent.type);
            }

            if (err != UV_EOF)
            {
                r->fail("listdir: Error reading directory entry (%s)", uv_strerror(err));
                return;
            }

            r->succeed(
                [entries = std::move(entries)](lua_State* L)
                {
                    lua_createtable(L, entries.size(), 0);
                    for (size_t i = 0; i < entries.size(); ++i)
                    {
                        lua_pushinteger(L, i + 1);

                        lua_createtable(L, 0, 2);

                        lua_pushstring(L, entries[i].first.c_str());
                        lua_setfield(L, -2, "name");

                        lua_pushstring(L, UV_DIRENT_TYPES[entries[i].second]);
                        lua_setfield(L, -2, "type");

                        lua_settable(L, -3);
                    }
                    return 1;
                }
            );
        }
    );

    return lua_yield(L, 0);
}

} // namespace fs
