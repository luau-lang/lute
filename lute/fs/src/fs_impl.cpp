#include "fs_impl.h"

#include "lute/uvutils.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

namespace fs
{

using FSRequest = uvutils::UVRequest<uv_fs_t>;

struct FSRead : FSRequest
{
    FSRead(lua_State* L, UVFile* file)
        : FSRequest(L)
        , file(file)
    {
        chunk.resize(4096);
        iov = uv_buf_init(chunk.data(), chunk.size());
        buffer.reserve(4096);
    }

    static void readCallback(uv_fs_t* req);

    static FSRead* from(uv_fs_t* req)
    {
        return static_cast<FSRead*>(req->data);
    }

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
        chunk.resize(4096);
    }

    static void writeCallback(uv_fs_t* req);

    static FSWrite* from(uv_fs_t* req)
    {
        return static_cast<FSWrite*>(req->data);
    }

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

    static FSClose* from(uv_fs_t* req)
    {
        return static_cast<FSClose*>(req->data);
    }

    UVFile* file = nullptr;
};

int open_impl(lua_State* L, const char* path, int flags, int mode)
{
    auto req = new FSRequest(L);
    uv_fs_open(
        uv_default_loop(),
        req->get(),
        path,
        flags,
        mode,
        [](uv_fs_t* req)
        {
            auto r = FSRequest::from(req);
            auto result = req->result;
            if (result < 0)
            {
                r->fail("Error opening file %s: %s", req->path, uv_strerror(result));
                delete r;
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

            delete r;
        }
    );
    return lua_yield(L, 0);
}

void FSRead::readCallback(uv_fs_t* req)
{
    auto r = FSRead::from(req);
    auto bytesRead = req->result;

    if (bytesRead < 0)
    {
        r->fail("Error reading file: %s", uv_strerror(bytesRead));
        delete r;
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
        delete r;
        return;
    }

    // Append the read data to our buffer
    r->buffer.insert(r->buffer.end(), r->chunk.begin(), r->chunk.begin() + bytesRead);

    // Zero out chunk buffer before next read
    std::fill(r->chunk.begin(), r->chunk.end(), 0);

    // Continue reading from current position
    uv_fs_read(uv_default_loop(), r->get(), r->file->fd.value(), &r->iov, 1, -1, FSRead::readCallback);
}

void FSWrite::writeCallback(uv_fs_t* req)
{
    auto w = FSWrite::from(req);
    auto bytesWritten = req->result;

    if (bytesWritten < 0)
    {
        w->fail("Error writing file: %s", uv_strerror(bytesWritten));
        delete w;
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

        delete w;
        return;
    }

    // Copy next chunk to write
    size_t remaining = w->toWrite.size() - w->offset;
    size_t chunkSize = std::min(remaining, w->chunk.size());
    std::copy(w->toWrite.begin() + w->offset, w->toWrite.begin() + w->offset + chunkSize, w->chunk.begin());
    w->iov = uv_buf_init(w->chunk.data(), chunkSize);

    uv_fs_write(uv_default_loop(), w->get(), w->file->fd.value(), &w->iov, 1, -1, FSWrite::writeCallback);
}

int read_impl(lua_State* L, UVFile* handle)
{
    if (!handle->fd.has_value())
    {
        luaL_errorL(L, "File handle is closed");
    }

    auto req = new FSRead(L, handle);
    uv_fs_read(uv_default_loop(), req->get(), handle->fd.value(), &req->iov, 1, -1, FSRead::readCallback);

    return lua_yield(L, 0);
}

int write_impl(lua_State* L, UVFile* handle, const char* toWrite, size_t numBytes)
{
    if (!handle->fd.has_value())
    {
        luaL_errorL(L, "File handle is closed");
    }

    auto req = new FSWrite(L, handle, toWrite, numBytes);

    // Copy first chunk to write
    size_t chunkSize = std::min(numBytes, req->chunk.size());
    std::copy(req->toWrite.begin(), req->toWrite.begin() + chunkSize, req->chunk.begin());
    req->iov = uv_buf_init(req->chunk.data(), chunkSize);

    uv_fs_write(uv_default_loop(), req->get(), handle->fd.value(), &req->iov, 1, -1, FSWrite::writeCallback);
    return lua_yield(L, 0);
}

int close_impl(lua_State* L, UVFile* handle)
{
    if (!handle->fd.has_value())
    {
        delete handle;
        luaL_errorL(L, "File handle is already closed");
    }

    auto req = new FSClose(L, handle);
    uv_fs_close(
        uv_default_loop(),
        req->get(),
        handle->fd.value(),
        [](uv_fs_t* req)
        {
            auto r = FSClose::from(req);
            auto result = req->result;

            if (result < 0)
            {
                r->fail("Error closing file: %s", uv_strerror(result));
                delete r;
                return;
            }

            r->succeed(
                [](lua_State* L)
                {
                    return 0;
                }
            );

            delete r;
        }
    );

    return lua_yield(L, 0);
}

} // namespace fs
