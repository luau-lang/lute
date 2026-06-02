#include "fs_impl.h"

#include "lute/time.h"
#include "lute/userdatas.h"
#include "lute/uvrequest.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include "Luau/VecDeque.h"

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
    using FSRequest::FSRequest;
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

struct FSRename : FSPathPairRequest
{
    using FSPathPairRequest::FSPathPairRequest;

    std::string linkTarget;

    static void renameCallback(uv_fs_t* req);
    static void statCallback(uv_fs_t* req);
    static void copyCallback(uv_fs_t* req);
    static void unlinkCallback(uv_fs_t* req);
    static void readlinkCallback(uv_fs_t* req);
    static void symlinkCallback(uv_fs_t* req);
#if _WIN32
    static void symlinkStatCallback(uv_fs_t* req);
#endif
};

// Handles a recursive cross-filesystem directory move as a self-managed async state machine.
// Ownership: heap-allocated; calls `delete this` via succeed() or fail().
struct FSCopyDirectory
{
    FSCopyDirectory(ResumeToken token, uv_loop_t* loop, std::string src, std::string dest)
        : token(std::move(token))
        , loop(loop)
    {
        req.data = this;
        pendingDirs.push_back({std::move(src), std::move(dest)});
    }

    struct DirPair
    {
        std::string src;
        std::string dest;
    };

    ResumeToken token;
    uv_loop_t* loop;
    uv_fs_t req;

    Luau::VecDeque<DirPair> pendingDirs;  // source dirs awaiting mkdir+scandir
    std::vector<std::string> scannedDirs; // source dirs in breadth-first order; rmdired in reverse
    std::vector<DirPair> pendingFiles;    // regular files awaiting copyfile+unlink
    std::vector<DirPair> pendingLinks;    // symlinks awaiting readlink+symlink+unlink
    size_t fileIdx = 0;
    size_t linkIdx = 0;
    size_t removeDirIdx = 0;
    std::string linkTarget; // readlink result held between readlinkCallback and symlinkCallback
    std::vector<DirPair> pendingUnknown; // dirent-unknown entries awaiting per-entry lstat classification
    size_t unknownIdx = 0;

    static FSCopyDirectory* fromReq(uv_fs_t* req)
    {
        return static_cast<FSCopyDirectory*>(req->data);
    }

    template<typename... Args>
    void fail(const char* fmt, Args&&... args)
    {
        int size = snprintf(nullptr, 0, fmt, std::forward<Args>(args)...);
        if (size < 0)
        {
            token->fail("Format error in fail");
            delete this;
            return;
        }

        std::vector<char> buffer(size + 1);
        snprintf(buffer.data(), buffer.size(), fmt, std::forward<Args>(args)...);
        token->fail(std::string(buffer.data()));

        delete this;
    }

    void succeed()
    {
        token->complete([](lua_State* L) { return 0; });
        delete this;
    }

    // Phase 1: process the next pending source directory, or advance to file copying.
    void start()
    {
        if (!pendingDirs.empty())
        {
            uv_fs_mkdir(loop, &req, pendingDirs.front().dest.c_str(), 0777, FSCopyDirectory::mkdirCallback);
            return;
        }

        startFileCopy();
    }

    // Phase 2: lstat each UV_DIRENT_UNKNOWN entry from the current scandir to classify it.
    void startUnknownClassification()
    {
        if (unknownIdx < pendingUnknown.size())
        {
            uv_fs_lstat(loop, &req, pendingUnknown[unknownIdx].src.c_str(), FSCopyDirectory::unknownLstatCallback);
            return;
        }

        pendingUnknown.clear();
        unknownIdx = 0;
        scannedDirs.push_back(pendingDirs.front().src);
        pendingDirs.pop_front();
        start();
    }

    // Phase 3: copy+unlink the next pending regular file, or advance to symlink recreation.
    void startFileCopy()
    {
        if (fileIdx < pendingFiles.size())
        {
            uv_fs_copyfile(loop, &req, pendingFiles[fileIdx].src.c_str(), pendingFiles[fileIdx].dest.c_str(), 0, FSCopyDirectory::copyFileCallback);
            return;
        }

        startLinkCopy();
    }

    // Phase 4: recreate symlinks at destination via readlink+symlink+unlink.
    void startLinkCopy()
    {
        if (linkIdx < pendingLinks.size())
        {
            uv_fs_readlink(loop, &req, pendingLinks[linkIdx].src.c_str(), FSCopyDirectory::readlinkCallback);
            return;
        }

        startDirRemoval();
    }

    // Phase 5: rmdir source dirs in reverse breadth-first order (children before parents).
    void startDirRemoval()
    {
        if (removeDirIdx < scannedDirs.size())
        {
            const auto& dir = scannedDirs[scannedDirs.size() - 1 - removeDirIdx];
            uv_fs_rmdir(loop, &req, dir.c_str(), FSCopyDirectory::rmdirCallback);
            return;
        }

        succeed();
    }

    static void mkdirCallback(uv_fs_t* req)
    {
        auto* self = fromReq(req);
        auto result = req->result;
        uv_fs_req_cleanup(req);

        if (result < 0 && result != UV_EEXIST)
        {
            self->fail("move: Error creating directory %s: %s", self->pendingDirs.front().dest.c_str(), uv_strerror(result));
            return;
        }

        uv_fs_scandir(self->loop, &self->req, self->pendingDirs.front().src.c_str(), 0, FSCopyDirectory::scandirCallback);
    }

    static void scandirCallback(uv_fs_t* req)
    {
        auto* self = fromReq(req);
        auto result = req->result;

        if (result < 0)
        {
            std::string srcPath = self->pendingDirs.front().src;
            uv_fs_req_cleanup(req);
            self->fail(
                "move: Error reading directory %s: %s; some destination subdirectories may have been created",
                srcPath.c_str(),
                uv_strerror(result)
            );
            return;
        }

        // Collect all entries before req_cleanup, which frees the scandir data.
        std::vector<std::pair<std::string, uv_dirent_type_t>> entries;
        uv_dirent_t dirent;
        int err;
        while ((err = uv_fs_scandir_next(req, &dirent)) >= 0)
            entries.emplace_back(dirent.name, dirent.type);

        std::string srcDir = self->pendingDirs.front().src;
        std::string destDir = self->pendingDirs.front().dest;
        uv_fs_req_cleanup(req);

        if (err != UV_EOF)
        {
            self->fail(
                "move: Error reading directory entry in %s: %s; some destination subdirectories may have been created",
                srcDir.c_str(),
                uv_strerror(err)
            );
            return;
        }

        for (auto& [name, type] : entries)
        {
            std::string childSrc = srcDir + "/" + name;
            std::string childDest = destDir + "/" + name;
            if (type == UV_DIRENT_DIR)
            {
                self->pendingDirs.push_back({childSrc, childDest});
            }
            else if (type == UV_DIRENT_FILE)
            {
                self->pendingFiles.push_back({childSrc, childDest});
            }
            else if (type == UV_DIRENT_LINK)
            {
                self->pendingLinks.push_back({childSrc, childDest});
            }
            else if (type == UV_DIRENT_UNKNOWN)
            {
                self->pendingUnknown.push_back({childSrc, childDest});
            }
            else
            {
                self->fail("move: Cannot move %s: unsupported file type", childSrc.c_str());
                return;
            }
        }

        if (!self->pendingUnknown.empty())
        {
            self->startUnknownClassification();
            return;
        }

        self->scannedDirs.push_back(srcDir);
        self->pendingDirs.pop_front();

        self->start();
    }

    static void unknownLstatCallback(uv_fs_t* req)
    {
        auto* self = fromReq(req);
        auto result = req->result;

        if (result < 0)
        {
            std::string path = self->pendingUnknown[self->unknownIdx].src;
            uv_fs_req_cleanup(req);
            self->fail(
                "move: Error reading %s: %s; some destination subdirectories may have been created",
                path.c_str(),
                uv_strerror(result)
            );
            return;
        }

        auto mode = req->statbuf.st_mode;
        const auto& entry = self->pendingUnknown[self->unknownIdx];

        if (S_ISDIR(mode))
        {
            self->pendingDirs.push_back({entry.src, entry.dest});
        }
        else if (S_ISREG(mode))
        {
            self->pendingFiles.push_back({entry.src, entry.dest});
        }
        else if (S_ISLNK(mode))
        {
            self->pendingLinks.push_back({entry.src, entry.dest});
        }
        else
        {
            std::string path = entry.src;
            uv_fs_req_cleanup(req);
            self->fail(
                "move: Cannot move %s: unsupported file type; some destination subdirectories may have been created",
                path.c_str()
            );
            return;
        }

        uv_fs_req_cleanup(req);
        ++self->unknownIdx;
        self->startUnknownClassification();
    }

    static void copyFileCallback(uv_fs_t* req)
    {
        auto* self = fromReq(req);
        auto result = req->result;
        uv_fs_req_cleanup(req);

        if (result < 0)
        {
            self->fail(
                "move: Error copying file %s: %s; source and destination may be in an inconsistent state",
                self->pendingFiles[self->fileIdx].src.c_str(),
                uv_strerror(result)
            );
            return;
        }

        uv_fs_unlink(self->loop, &self->req, self->pendingFiles[self->fileIdx].src.c_str(), FSCopyDirectory::unlinkFileCallback);
    }

    static void unlinkFileCallback(uv_fs_t* req)
    {
        auto* self = fromReq(req);
        auto result = req->result;
        uv_fs_req_cleanup(req);

        if (result < 0)
        {
            self->fail(
                "move: Error removing source file %s: %s; source and destination may be in an inconsistent state",
                self->pendingFiles[self->fileIdx].src.c_str(),
                uv_strerror(result)
            );
            return;
        }

        ++self->fileIdx;
        self->startFileCopy();
    }

    static void readlinkCallback(uv_fs_t* req)
    {
        auto* self = fromReq(req);
        auto result = req->result;

        if (result < 0)
        {
            std::string src = self->pendingLinks[self->linkIdx].src;
            uv_fs_req_cleanup(req);
            self->fail(
                "move: Error reading symlink %s: %s; source and destination may be in an inconsistent state",
                src.c_str(),
                uv_strerror(result)
            );
            return;
        }

        // req->ptr holds the link target; copy it before cleanup frees it.
        self->linkTarget = static_cast<const char*>(req->ptr);
        uv_fs_req_cleanup(req);

#if _WIN32
        uv_fs_stat(self->loop, &self->req, self->linkTarget.c_str(), FSCopyDirectory::symlinkStatCallback);
#else
        uv_fs_symlink(self->loop, &self->req, self->linkTarget.c_str(), self->pendingLinks[self->linkIdx].dest.c_str(), 0, FSCopyDirectory::symlinkCallback);
#endif
    }

#if _WIN32
    static void symlinkStatCallback(uv_fs_t* req)
    {
        auto* self = fromReq(req);
        int flags = (req->result >= 0 && S_ISDIR(req->statbuf.st_mode)) ? UV_FS_SYMLINK_DIR : 0;
        uv_fs_req_cleanup(req);
        uv_fs_symlink(self->loop, &self->req, self->linkTarget.c_str(), self->pendingLinks[self->linkIdx].dest.c_str(), flags, FSCopyDirectory::symlinkCallback);
    }
#endif

    static void symlinkCallback(uv_fs_t* req)
    {
        auto* self = fromReq(req);
        auto result = req->result;
        uv_fs_req_cleanup(req);

        if (result < 0)
        {
            self->fail(
                "move: Error creating symlink %s: %s; source and destination may be in an inconsistent state",
                self->pendingLinks[self->linkIdx].dest.c_str(),
                uv_strerror(result)
            );
            return;
        }

        uv_fs_unlink(self->loop, &self->req, self->pendingLinks[self->linkIdx].src.c_str(), FSCopyDirectory::unlinkLinkCallback);
    }

    static void unlinkLinkCallback(uv_fs_t* req)
    {
        auto* self = fromReq(req);
        auto result = req->result;
        uv_fs_req_cleanup(req);

        if (result < 0)
        {
            self->fail(
                "move: Error removing source symlink %s: %s; source and destination may be in an inconsistent state",
                self->pendingLinks[self->linkIdx].src.c_str(),
                uv_strerror(result)
            );
            return;
        }

        ++self->linkIdx;
        self->startLinkCopy();
    }

    static void rmdirCallback(uv_fs_t* req)
    {
        auto* self = fromReq(req);
        auto result = req->result;
        uv_fs_req_cleanup(req);

        if (result < 0)
        {
            self->fail(
                "move: Error removing source directory %s: %s; the destination is complete but the source directory tree was not fully removed",
                self->scannedDirs[self->scannedDirs.size() - 1 - self->removeDirIdx].c_str(),
                uv_strerror(result)
            );
            return;
        }

        ++self->removeDirIdx;
        self->startDirRemoval();
    }
};

int open_impl(lua_State* L, const char* path, int flags, int mode)
{
    uvutils::ScopedUVRequest<FSRequest> req(L);
    uv_fs_open(
        req->getLoop(),
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
                    void* storage = lua_newuserdatataggedwithmetatable(L, sizeof(UVFile), kUVFileTag);
                    auto* file = new (storage) UVFile();
                    file->fd = result;
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

    uvutils::ScopedUVRequest<FSRead> scopedReq{std::move(r)};
    uv_fs_read(scopedReq->getLoop(), &scopedReq->req, scopedReq->file->fd.value(), &scopedReq->iov, 1, -1, FSRead::readCallback);
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
        w->succeedTrivially();

        return;
    }

    // Copy next chunk to write
    size_t remaining = w->toWrite.size() - w->offset;
    size_t chunkSize = std::min(remaining, w->chunk.size());
    std::copy(w->toWrite.begin() + w->offset, w->toWrite.begin() + w->offset + chunkSize, w->chunk.begin());
    w->iov = uv_buf_init(w->chunk.data(), chunkSize);

    uvutils::ScopedUVRequest<FSWrite> scopedReq{std::move(w)};
    uv_fs_write(scopedReq->getLoop(), &scopedReq->req, scopedReq->file->fd.value(), &scopedReq->iov, 1, -1, FSWrite::writeCallback);
}

int read_impl(lua_State* L, UVFile* handle)
{
    if (!handle->fd.has_value())
    {
        luaL_errorL(L, "File handle is closed");
    }

    uvutils::ScopedUVRequest<FSRead> req{L, handle};
    uv_fs_read(req->getLoop(), &req->req, handle->fd.value(), &req->iov, 1, -1, FSRead::readCallback);
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

    uv_fs_write(req->getLoop(), &req->req, handle->fd.value(), &req->iov, 1, -1, FSWrite::writeCallback);

    return lua_yield(L, 0);
}

int close_impl(lua_State* L, UVFile* handle)
{
    if (!handle->fd.has_value())
    {
        luaL_errorL(L, "File handle is already closed");
    }

    auto fd = handle->fd.value();
    handle->fd = std::nullopt;

    uvutils::ScopedUVRequest<FSClose> req{L};
    uv_fs_close(
        req->getLoop(),
        &req->req,
        fd,
        [](uv_fs_t* req)
        {
            auto r = uvutils::retake<FSClose>(req);
            auto result = req->result;

            if (result < 0)
            {
                r->fail("Error closing file: %s", uv_strerror(result));
                return;
            }

            r->succeedTrivially();
        }
    );

    return lua_yield(L, 0);
}

int remove_impl(lua_State* L, const char* path)
{
    uvutils::ScopedUVRequest<FSRequest> req(L);
    uv_fs_unlink(
        req->getLoop(),
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

            r->succeedTrivially();
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

static int createDurationFromTimespec(lua_State* L, uv_timespec_t timespec)
{
    uv_timespec64_t extended{static_cast<int64_t>(timespec.tv_sec), static_cast<int32_t>(timespec.tv_nsec)};
    return createDurationFromTimespec(L, extended);
}

int stat_impl(lua_State* L, const char* path)
{
    uvutils::ScopedUVRequest<FSRequest> req(L);
    uv_fs_stat(
        req->getLoop(),
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

                    createDurationFromTimespec(L, stat.st_birthtim);
                    lua_setfield(L, -2, "created");

                    createDurationFromTimespec(L, stat.st_atim);
                    lua_setfield(L, -2, "accessed");

                    createDurationFromTimespec(L, stat.st_mtim);
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
        req->getLoop(),
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
        req->getLoop(),
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
        req->getLoop(),
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

            r->succeedTrivially();
        }
    );

    return lua_yield(L, 0);
}

#if _WIN32
struct FSSymlink : FSPathPairRequest
{
    using FSPathPairRequest::FSPathPairRequest;

    static void statCallback(uv_fs_t* req)
    {
        auto r = uvutils::retake<FSSymlink>(req);
        int flags = (req->result >= 0 && S_ISDIR(req->statbuf.st_mode)) ? UV_FS_SYMLINK_DIR : 0;

        uv_fs_req_cleanup(&r->req);
        uvutils::ScopedUVRequest<FSSymlink> symlinkReq{std::move(r)};
        uv_fs_symlink(
            symlinkReq->getLoop(),
            &symlinkReq->req,
            symlinkReq->src.c_str(),
            symlinkReq->dest.c_str(),
            flags,
            FSSymlink::symlinkCallback
        );
    }

    static void symlinkCallback(uv_fs_t* req)
    {
        auto r = uvutils::retake<FSSymlink>(req);
        auto result = req->result;

        if (result < 0)
        {
            r->fail("symlink: Error creating symlink from %s to %s: %s", r->src.c_str(), r->dest.c_str(), uv_strerror(result));
            return;
        }

        r->succeedTrivially();
    }
};
#endif

int symlink_impl(lua_State* L, const char* path, const char* dest)
{
#if _WIN32
    uvutils::ScopedUVRequest<FSSymlink> req{L, path, dest};
    uv_fs_stat(req->getLoop(), &req->req, path, FSSymlink::statCallback);
#else
    uvutils::ScopedUVRequest<FSPathPairRequest> req{L, path, dest};
    uv_fs_symlink(
        req->getLoop(),
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
                r->fail("symlink: Error creating symlink from %s to %s: %s", r->src.c_str(), r->dest.c_str(), uv_strerror(result));
                return;
            }

            r->succeedTrivially();
        }
    );
#endif

    return lua_yield(L, 0);
}

int copy_impl(lua_State* L, const char* path, const char* dest)
{
    uvutils::ScopedUVRequest<FSPathPairRequest> req{L, path, dest};
    uv_fs_copyfile(
        req->getLoop(),
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

            r->succeedTrivially();
        }
    );

    return lua_yield(L, 0);
}

void FSRename::renameCallback(uv_fs_t* req)
{
    auto r = uvutils::retake<FSRename>(req);
    auto result = req->result;

    if (result == 0)
    {
        r->succeedTrivially();
        return;
    }

    if (result != UV_EXDEV)
    {
        r->fail("move: Error moving %s to %s: %s", r->src.c_str(), r->dest.c_str(), uv_strerror(result));
        return;
    }

    // Cross-filesystem: stat the source first to determine whether it's a file or a directory,
    // since the fallback copy strategy differs between the two.
    uv_fs_req_cleanup(&r->req);
    uvutils::ScopedUVRequest<FSRename> statReq{std::move(r)};
    uv_fs_lstat(statReq->getLoop(), &statReq->req, statReq->src.c_str(), FSRename::statCallback);
}

void FSRename::statCallback(uv_fs_t* req)
{
    auto r = uvutils::retake<FSRename>(req);
    auto result = req->result;

    if (result < 0)
    {
        r->fail("move: Error reading source %s: %s", r->src.c_str(), uv_strerror(result));
        return;
    }

    if (S_ISLNK(req->statbuf.st_mode))
    {
        // Top-level source is a symlink: recreate it at the destination.
        uv_fs_req_cleanup(&r->req);
        uvutils::ScopedUVRequest<FSRename> readlinkReq{std::move(r)};
        uv_fs_readlink(readlinkReq->getLoop(), &readlinkReq->req, readlinkReq->src.c_str(), FSRename::readlinkCallback);
        return;
    }

    if (S_ISDIR(req->statbuf.st_mode))
    {
        // Directory: hand off to FSCopyDirectory. Moving the token transfers coroutine
        // ownership; r is then destroyed cleanly with an empty token.
        new FSCopyDirectory(std::move(r->token), r->loop, r->src, r->dest);
        return;
    }

    // Regular file (or other): use the existing async copyfile → unlink chain.
    uvutils::ScopedUVRequest<FSRename> copyReq{std::move(r)};
    uv_fs_copyfile(copyReq->getLoop(), &copyReq->req, copyReq->src.c_str(), copyReq->dest.c_str(), 0, FSRename::copyCallback);
}

void FSRename::copyCallback(uv_fs_t* req)
{
    auto r = uvutils::retake<FSRename>(req);
    auto result = req->result;

    if (result < 0)
    {
        r->fail("move: Error copying %s to %s: %s", r->src.c_str(), r->dest.c_str(), uv_strerror(result));
        return;
    }

    uv_fs_req_cleanup(&r->req);
    uvutils::ScopedUVRequest<FSRename> unlinkReq{std::move(r)};
    uv_fs_unlink(unlinkReq->getLoop(), &unlinkReq->req, unlinkReq->src.c_str(), FSRename::unlinkCallback);
}

void FSRename::unlinkCallback(uv_fs_t* req)
{
    auto r = uvutils::retake<FSRename>(req);
    auto result = req->result;

    if (result < 0)
    {
        r->fail("move: Error removing source %s: %s", r->src.c_str(), uv_strerror(result));
        return;
    }

    r->succeedTrivially();
}

void FSRename::readlinkCallback(uv_fs_t* req)
{
    auto r = uvutils::retake<FSRename>(req);
    auto result = req->result;

    if (result < 0)
    {
        r->fail("move: Error reading symlink %s: %s", r->src.c_str(), uv_strerror(result));
        return;
    }

    r->linkTarget = static_cast<const char*>(req->ptr);
    uv_fs_req_cleanup(&r->req);

#if _WIN32
    uvutils::ScopedUVRequest<FSRename> statReq{std::move(r)};
    uv_fs_stat(statReq->getLoop(), &statReq->req, statReq->linkTarget.c_str(), FSRename::symlinkStatCallback);
#else
    uvutils::ScopedUVRequest<FSRename> symlinkReq{std::move(r)};
    uv_fs_symlink(symlinkReq->getLoop(), &symlinkReq->req, symlinkReq->linkTarget.c_str(), symlinkReq->dest.c_str(), 0, FSRename::symlinkCallback);
#endif
}

#if _WIN32
void FSRename::symlinkStatCallback(uv_fs_t* req)
{
    auto r = uvutils::retake<FSRename>(req);
    int flags = (req->result >= 0 && S_ISDIR(req->statbuf.st_mode)) ? UV_FS_SYMLINK_DIR : 0;
    uv_fs_req_cleanup(&r->req);
    uvutils::ScopedUVRequest<FSRename> symlinkReq{std::move(r)};
    uv_fs_symlink(symlinkReq->getLoop(), &symlinkReq->req, symlinkReq->linkTarget.c_str(), symlinkReq->dest.c_str(), flags, FSRename::symlinkCallback);
}
#endif

void FSRename::symlinkCallback(uv_fs_t* req)
{
    auto r = uvutils::retake<FSRename>(req);
    auto result = req->result;

    if (result < 0)
    {
        r->fail("move: Error creating symlink %s: %s", r->dest.c_str(), uv_strerror(result));
        return;
    }

    uv_fs_req_cleanup(&r->req);
    uvutils::ScopedUVRequest<FSRename> unlinkReq{std::move(r)};
    uv_fs_unlink(unlinkReq->getLoop(), &unlinkReq->req, unlinkReq->src.c_str(), FSRename::unlinkCallback);
}

int rename_impl(lua_State* L, const char* path, const char* dest)
{
    uvutils::ScopedUVRequest<FSRename> req{L, path, dest};
    uv_fs_rename(req->getLoop(), &req->req, path, dest, FSRename::renameCallback);
    return lua_yield(L, 0);
}

int mkdir_impl(lua_State* L, const char* path, int mode)
{
    uvutils::ScopedUVRequest<FSRequest> req(L);
    uv_fs_mkdir(
        req->getLoop(),
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

            r->succeedTrivially();
        }
    );

    return lua_yield(L, 0);
}


int rmdir_impl(lua_State* L, const char* path)
{
    uvutils::ScopedUVRequest<FSRequest> req(L);
    uv_fs_rmdir(
        req->getLoop(),
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

            r->succeedTrivially();
        }
    );

    return lua_yield(L, 0);
}


int listdir_impl(lua_State* L, const char* path)
{
    uvutils::ScopedUVRequest<FSRequest> req(L);
    uv_fs_scandir(
        req->getLoop(),
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
