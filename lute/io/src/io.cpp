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
    uv_stream_t* stream = nullptr;
    uv_loop_t* loop = nullptr;
    ResumeToken resumeToken;
    lua_State* L = nullptr;
    std::shared_ptr<IOHandle> self;
    uv_buf_t *buf;

    ~IOHandle() {
        if (buf) {
            free(buf->base);
            buf = nullptr;
        }
    }

    void closeHandles()
    {
        auto closeCb = [](uv_handle_t* handle)
        {
            IOHandle* ioh = static_cast<IOHandle*>(handle->data);
            ioh->self.reset();
        };

        uv_read_stop((uv_stream_t*)stream);
        uv_close((uv_handle_t*)stream, closeCb);
    }
};

static void allocBuffer(uv_handle_t* handle, size_t suggestedSize, uv_buf_t* buf)
{
    buf->base = (char*)malloc(suggestedSize);
    buf->len = buf->base ? suggestedSize : 0;
    if (!buf->base)
    {
        fprintf(stderr, "Process pipe buffer allocation failed!\n");
    }
    static_cast<IOHandle*>(handle->data)->buf = buf;
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
        handle->resumeToken->fail("Error reading from stdin");
    }
    else if (nread == UV_EOF)
    {
        handle->resumeToken->fail("EOF reached");
    }

    handle->closeHandles();
}

int input(lua_State* L)
{
    auto handle = std::make_shared<IOHandle>();
    handle->loop = uv_default_loop();
    handle->resumeToken = getResumeToken(L);
    handle->L = L;
    handle->self = handle;

    uv_handle_type ht = uv_guess_handle(fileno(stdin));
    if (ht == UV_TTY)
    {
        uv_tty_t& tty = handle->streamVariant.emplace<uv_tty_t>();
        handle->stream = (uv_stream_t*)&tty;
        uv_tty_init(handle->loop, (uv_tty_t*)&tty, fileno(stdin), 0);
        handle->stream->data = handle.get();
    }
    else if (ht == UV_NAMED_PIPE || ht == UV_FILE)
    {
        uv_pipe_t& pipe = handle->streamVariant.emplace<uv_pipe_t>();
        handle->stream = (uv_stream_t*)&pipe;
        uv_pipe_init(handle->loop, &pipe, 0);
        uv_pipe_open(&pipe, fileno(stdin));
        handle->stream->data = handle.get();
    }
    else
    {
        handle->resumeToken->fail("Unsupported stdin type");
        return 0;
    }

    uv_read_start(handle->stream, allocBuffer, onTtyRead);
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
