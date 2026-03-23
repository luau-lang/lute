#pragma once

#include "lute/common.h"

#include "uv.h"

#include <functional>
#include <optional>
#include <string>
#include <string_view>

namespace uvutils
{

using OnRead = std::function<void(std::string_view)>;
using OnStreamEnd = std::function<void(std::optional<std::string>)>;
using OnClose = std::function<void()>;

struct StreamCallbacks
{
    OnRead onRead;
    OnStreamEnd onStreamEnd;
    OnClose onClose;
};

template<typename T>
struct UVStream
{

    UVStream(uv_loop_t* loop, std::string handleContext = "")
        : loop(loop)
        , handleContext(handleContext)
        , closed(false)
    {
        stream.data = this;
    }

    UVStream(const UVStream&) = delete;
    UVStream& operator=(const UVStream&) = delete;
    UVStream(UVStream&&) = delete;
    UVStream& operator=(UVStream&&) = delete;

    T* getStream()
    {
        return static_cast<T*>(&stream);
    }

    void read(OnRead&& onRead, OnStreamEnd&& onStreamEnd)
    {
        callbacks.onRead = onRead;
        callbacks.onStreamEnd = onStreamEnd;
        uv_read_start((uv_stream_t*)&stream, allocBuffer, readStream);
    }

    bool isClosed() const
    {
        return closed;
    }

    void close(OnClose&& onClose)
    {
        if (isClosed())
            return;
        callbacks.onClose = std::move(onClose);
        if (!uv_is_closing((uv_handle_t*)&stream))
        {
            uv_read_stop((uv_stream_t*)&stream);
            uv_close(
                (uv_handle_t*)&stream,
                [](uv_handle_t* handle)
                {
                    auto stream = static_cast<UVStream<T>*>(handle->data);
                    LUTE_ASSERT(stream);
                    stream->closed = true;
                    stream->callbacks.onClose();
                }
            );
        }
    }

    static void allocBuffer(uv_handle_t* handle, size_t newSize, uv_buf_t* buf)
    {
        buf->base = (char*)malloc(newSize);
        buf->len = buf->base ? newSize : 0;
        auto uvStream = static_cast<UVStream<T>*>(handle->data);
        LUTE_ASSERT(uvStream);
        if (!buf->base)
        {
            uvStream->callbacks.onStreamEnd("Failed to allocate memory");
        }
    }

    static void readStream(uv_stream_t* stream, ssize_t nread, const uv_buf_t* buf)
    {
        auto handle = static_cast<UVStream<T>*>(stream->data);
        if (!handle)
        {
            if (buf->base)
                free(buf->base);
            return;
        }

        if (nread > 0)
        {
            handle->callbacks.onRead(std::string_view(buf->base, nread));
        }
        else if (nread < 0)
        {
            std::optional<std::string> error = std::nullopt;
            if (nread != UV_EOF)
            {
                std::string msg = handle->handleContext + ": " + uv_strerror(nread);
                error.emplace(msg);
            }
            handle->callbacks.onStreamEnd(error);
        }

        if (buf->base)
        {
            free(buf->base);
        }
    }

    T stream;
    uv_loop_t* loop;
    StreamCallbacks callbacks;
    std::string handleContext;
    bool closed = false;
};


struct PipeStream : UVStream<uv_pipe_t>
{

    PipeStream(uv_loop_t* loop, bool ipc, std::string handleContext)
        : UVStream<uv_pipe_t>(loop, handleContext)
    {
        uv_pipe_init(loop, &stream, ipc);
    }
};


} // namespace uvutils
