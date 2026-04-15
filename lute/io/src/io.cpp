#include "lute/io.h"

#include "lute/runtime.h"

#include "Luau/Variant.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include <memory>


namespace
{

struct IOHandle
{
    Luau::Variant<uv_pipe_t, uv_tty_t> streamVariant;
    uv_loop_t* loop = nullptr;
    ResumeToken resumeToken;
    std::shared_ptr<IOHandle> self;
    std::vector<char> buffer;
    uv_write_t writeReq;
    uv_buf_t iov;

    static void closeCb(uv_handle_t* handle)
    {
        IOHandle* ioh = static_cast<IOHandle*>(handle->data);
        ioh->self.reset();
    }

    void close()
    {
        uv_stream_t* stream = getStream();
        uv_read_stop(stream);
        uv_close((uv_handle_t*)stream, closeCb);
    }

    uv_stream_t* getStream()
    {
        return Luau::visit(
            [](auto& stream) -> uv_stream_t*
            {
                return (uv_stream_t*)&stream;
            },
            streamVariant
        );
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

    handle->close();
}

static void onWrite(uv_write_t* req, int status)
{
    IOHandle* handle = static_cast<IOHandle*>(req->data);

    if (status < 0)
        handle->resumeToken->fail(uv_strerror(status));
    else
        handle->resumeToken->complete(
            [](lua_State* L)
            {
                return 0;
            }
        );

    handle->close();
}

int write(lua_State* L)
{
    int nargs = lua_gettop(L);

    std::string toWrite;
    for (int i = 1; i <= nargs; i++)
    {
        size_t len;
        const char* str = luaL_checklstring(L, i, &len);
        toWrite.append(str, len);
    }

    if (toWrite.empty())
        return 0;

    auto handle = std::make_shared<IOHandle>();
    handle->loop = getRuntimeLoop(L);
    handle->resumeToken = getResumeToken(L);
    handle->self = handle;
    handle->buffer.assign(toWrite.begin(), toWrite.end());

    uv_handle_type ht = uv_guess_handle(fileno(stdout));
    if (ht == UV_TTY)
    {
        uv_tty_t& tty = handle->streamVariant.emplace<uv_tty_t>();
        int status = uv_tty_init(handle->loop, &tty, fileno(stdout), 0);
        if (status < 0)
            luaL_error(L, "Failed to initialize TTY: %s", uv_strerror(status));
    }
    else if (ht == UV_NAMED_PIPE || ht == UV_FILE)
    {
        uv_pipe_t& pipe = handle->streamVariant.emplace<uv_pipe_t>();
        int status = uv_pipe_init(handle->loop, &pipe, 0);
        if (status < 0)
            luaL_error(L, "Failed to initialize pipe: %s", uv_strerror(status));
        uv_pipe_open(&pipe, fileno(stdout));
    }
    else
    {
        luaL_error(L, "Unsupported stdout type");
    }

    uv_stream_t* stream = handle->getStream();
    stream->data = handle.get();
    handle->iov = uv_buf_init(handle->buffer.data(), handle->buffer.size());
    handle->writeReq.data = handle.get();
    uv_write(&handle->writeReq, stream, &handle->iov, 1, onWrite);

    return lua_yield(L, 0);
}

int read(lua_State* L)
{
    auto handle = std::make_shared<IOHandle>();
    handle->loop = getRuntimeLoop(L);
    handle->resumeToken = getResumeToken(L);
    handle->self = handle;

    uv_handle_type ht = uv_guess_handle(fileno(stdin));
    if (ht == UV_TTY)
    {
        uv_tty_t& tty = handle->streamVariant.emplace<uv_tty_t>();
        int status = uv_tty_init(handle->loop, &tty, fileno(stdin), 0);
        if (status < 0)
            luaL_error(L, "Failed to initialize TTY: %s", uv_strerror(status));
    }
    else if (ht == UV_NAMED_PIPE || ht == UV_FILE)
    {
        uv_pipe_t& pipe = handle->streamVariant.emplace<uv_pipe_t>();
        int status = uv_pipe_init(handle->loop, static_cast<uv_pipe_t*>(&pipe), 0);
        if (status < 0)
            luaL_error(L, "Failed to initialize pipe: %s", uv_strerror(status));
        uv_pipe_open(static_cast<uv_pipe_t*>(&pipe), fileno(stdin));
    }
    else
    {
        luaL_error(L, "Unsupported stdin type");
    }

    uv_stream_t* stream = handle->getStream();
    stream->data = handle.get();
    uv_read_start(stream, allocBuffer, onTtyRead);
    return lua_yield(L, 0);
}

} // anonymous namespace

const char* const IO::properties[] = {nullptr};

const luaL_Reg IO::lib[] = {
    {"write", write},
    {"read", read},
    {nullptr, nullptr},
};

int IO::pushLibrary(lua_State* L)
{
    lua_createtable(L, 0, std::size(IO::lib));

    for (auto& [name, func] : IO::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    return 1;
}

int luaopen_io(lua_State* L)
{
    return IO::openAsGlobal(L);
}

int luteopen_io(lua_State* L)
{
    return IO::pushLibrary(L);
}
