#pragma once

#include "lute/common.h"

#include "uv.h"

#include <functional>
#include <memory>
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
        : stream(std::make_unique<T>())
        , loop(loop)

        , handleContext(std::move(handleContext))
        , closed(false)
    {

        stream->data = this;
    }

    UVStream(const UVStream&) = delete;
    UVStream& operator=(const UVStream&) = delete;
    UVStream(UVStream&&) = delete;
    UVStream& operator=(UVStream&&) = delete;

    uv_stream_t* getStream()
    {
        return (uv_stream_t*)stream.get();
    }

    void read(OnRead&& onRead, OnStreamEnd&& onStreamEnd)
    {
        callbacks.onRead = std::move(onRead);
        callbacks.onStreamEnd = std::move(onStreamEnd);
        uv_read_start(getStream(), allocBuffer, readStream);
    }

    bool isClosed() const
    {
        return closed;
    }

    // Returns true if the close callback was registered successfully, false if the handle is already closed or closing.
    bool close(OnClose&& onClose)
    {
        if (isClosed())
            return false;
        if (uv_is_closing((uv_handle_t*)getStream()))
            return false;
        callbacks.onClose = std::move(onClose);
        uv_read_stop(getStream());
        uv_close(
            (uv_handle_t*)getStream(),
            [](uv_handle_t* handle)
            {
                auto stream = static_cast<UVStream<T>*>(handle->data);
                LUTE_ASSERT(stream);
                stream->closed = true;
                stream->callbacks.onClose();
            }
        );
        return true;
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

    std::unique_ptr<T> stream;
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
        uv_pipe_init(loop, stream.get(), ipc);
    }
};


} // namespace uvutils
