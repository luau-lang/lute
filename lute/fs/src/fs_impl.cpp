#include "fs_impl.h"

#include "lute/UVRequest.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

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

} // namespace fs
