#include "lute/io.h"
#include "Luau/Variant.h"
#include "lute/runtime.h"

#include <uv.h>
#include <memory>

#include "lua.h"
#include "lualib.h"


namespace io
{

struct IOHandle
{
    Luau::Variant<uv_pipe_t, uv_tty_t> streamVariant;
    uv_loop_t* loop = nullptr;
    ResumeToken resumeToken;
    std::shared_ptr<IOHandle> self;
    std::vector<char> buffer;

    ~IOHandle() {}

    void closeHandles()
    {
        auto closeCb = [](uv_handle_t* handle)
        {
            IOHandle* ioh = static_cast<IOHandle*>(handle->data);
            ioh->self.reset();
        };

        uv_stream_t *stream = getStream();
        uv_read_stop(stream);
        uv_close((uv_handle_t*)stream, closeCb);
    }

    uv_stream_t* getStream() {
        if (auto* tty = streamVariant.get_if<uv_tty_t>())
            return (uv_stream_t*)tty;
        if (auto* pipe = streamVariant.get_if<uv_pipe_t>())
            return (uv_stream_t*)pipe;
        return nullptr;
    }
};

static void allocBuffer(uv_handle_t* handle, size_t suggestedSize, uv_buf_t* buf)
{
    IOHandle* ioh = static_cast<IOHandle*>(handle->data);
    ioh->buffer.resize(suggestedSize);
    buf->base = ioh->buffer.data();
    buf->len = ioh->buffer.size();
}

// IOHandle is closed immediately after one read since we don't need a long running stream for this API.
static void onTtyRead(uv_stream_t* stream, ssize_t nread, const uv_buf_t* buf)
{
    IOHandle* handle = static_cast<IOHandle*>(stream->data);

    if (nread > 0)
    {
        handle->resumeToken->complete(
            [data = std::string(buf->base, nread)](lua_State* L) -> int
            {
                lua_pushlstring(L, data.c_str(), data.size());
                return 1;
            }
        );
    }
    else if (nread < 0)
    {
        handle->resumeToken->fail(uv_strerror(nread));
    }

    handle->closeHandles();
}

int read(lua_State* L)
{
    auto handle = std::make_shared<IOHandle>();
    handle->loop = uv_default_loop();
    handle->resumeToken = getResumeToken(L);
    handle->self = handle;

    uv_handle_type ht = uv_guess_handle(fileno(stdin));
    if (ht == UV_TTY)
    {
        uv_tty_t& tty = handle->streamVariant.emplace<uv_tty_t>();
        if (int status = uv_tty_init(handle->loop, (uv_tty_t*)&tty, fileno(stdin), 0); status < 0)
            luaL_error(L, "Failed to initialize TTY: %s", uv_strerror(status));
    }
    else if (ht == UV_NAMED_PIPE || ht == UV_FILE)
    {
        uv_pipe_t& pipe = handle->streamVariant.emplace<uv_pipe_t>();
        if (int status = uv_pipe_init(handle->loop, static_cast<uv_pipe_t*>(&pipe), 0); status < 0)
            luaL_error(L, "Failed to initialize pipe: %s", uv_strerror(status));
        uv_pipe_open(static_cast<uv_pipe_t*>(&pipe), fileno(stdin));
    }
    else
    {
        luaL_error(L, "Unsupported stdin type");
    }

    uv_stream_t *stream = handle->getStream();
    stream->data = handle.get();
    uv_read_start(stream, allocBuffer, onTtyRead);
    return lua_yield(L, 0);
}

} // namespace io

int luaopen_io(lua_State* L)
{
    luaL_register(L, "io", io::lib);
    return 1;
}

int luteopen_io(lua_State* L)
{
    lua_createtable(L, 0, std::size(io::lib));

    for (auto& [name, func] : io::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    return 1;
}
