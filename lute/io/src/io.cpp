#include "lute/io.h"

#include "lute/runtime.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include <memory>
#include <string>

namespace
{

// `IOHandle` is forward-declared so `StdinHandleOwner` can hold a `shared_ptr` to it.
struct IOHandle;

// Owns the `IOHandle` via a `shared_ptr`. Stored as light userdata in the Luau V.
// This leaks 16 bytes per process to allow for a single shared handle.
struct StdinHandleOwner
{
    std::shared_ptr<IOHandle> handle;
};

// Persistent handle for stdin. Created once on the first `io.read()` call and
// kept alive for the lifetime of the process (or until stdin reaches EOF/error).
// We never call `uv_close` between reads, only `uv_read_stop`, so the underlying
// file descriptor is never closed out from under the caller.
//
// The UV stream handle is heap-allocated separately so it can outlive the
// `IOHandle` during the async `uv_close`: the destructor schedules the close and
// the close callback simply deletes the libuv struct, with no access back to the
// (already-destroyed) `IOHandle`.
struct IOHandle
{
    uv_pipe_t* stream = nullptr;
    uv_loop_t* loop = nullptr;
    std::vector<char> readBuf;          // scratch buffer for libuv's alloc callback
    std::string lineBuffer;             // accumulated bytes; may span multiple reads
    ResumeToken pendingToken;           // coroutine currently waiting for a line
    StdinHandleOwner* owner = nullptr;

    ~IOHandle()
    {
        if (!stream)
            return;

        uv_read_stop(reinterpret_cast<uv_stream_t*>(stream));
        stream->data = nullptr;

        uv_close(
            (uv_handle_t*)stream,
            [](uv_handle_t* h)
            {
                // The `IOHandle` is already destroyed; just free the libuv struct.
                delete reinterpret_cast<uv_pipe_t*>(h);
            }
        );
    }
};

static const char* kStdinOwnerKey = "lute_io_stdin_owner";

// Returns the live stdin IOHandle, creating and initialising it on first call.
// Returns nullptr (and leaves a Lua error pending) if initialisation fails.
static IOHandle* getStdinHandle(lua_State* L, uv_loop_t* loop)
{
    lua_getfield(L, LUA_REGISTRYINDEX, kStdinOwnerKey);

    StdinHandleOwner* owner = nullptr;

    // if the field is not already present, then we need to initialize a handle.
    if (lua_isnil(L, -1))
    {
        lua_pop(L, 1);
        owner = new StdinHandleOwner();
        lua_pushlightuserdata(L, owner);
        lua_setfield(L, LUA_REGISTRYINDEX, kStdinOwnerKey);
    }
    else
    {
	    owner = static_cast<StdinHandleOwner*>(lua_tolightuserdata(L, -1));
        lua_pop(L, 1);

        // if the handle is present, we can return it immediately.
        if (owner->handle)
            return owner->handle.get();

        // otherwise, we'll fall through to the initialization code below to create a new handle and update the owner.
    }

    auto handle = std::make_shared<IOHandle>();
    handle->loop = loop;
    handle->owner = owner;
    owner->handle = handle;

    // Use uv_pipe_t for all stdin types, including TTY.
    //
    // uv_tty_t is intentionally avoided: uv_tty_init() on macOS calls dup2()
    // which closes the original stdin fd, and uv_read_start on a uv_tty_t puts
    // the terminal into raw mode (disabling ICRNL, ICANON, ISIG, ECHO). Both
    // are wrong for io.read(): raw mode breaks line editing, echo, Ctrl-C, and
    // the \r -> \n translation that lets lineBuffer.find('\n') work.
    //
    // uv_pipe_t leaves the terminal in its default cooked mode and does not
    // modify the fd, which is exactly what io.read() needs.
    uv_pipe_t* pipe = new uv_pipe_t;
    int initStatus = uv_pipe_init(loop, pipe, 0);
    if (initStatus < 0)
    {
        delete pipe;
        owner->handle.reset();
        luaL_error(L, "Failed to initialize stdin: %s", uv_strerror(initStatus));
    }

    int openStatus = uv_pipe_open(pipe, fileno(stdin));
    if (openStatus < 0)
    {
        // `uv_pipe_init` registered the handle; `uv_close` is needed to free it.
        // Set stream so `~IOHandle` will close it when `owner->handle` is reset.
        handle->stream = pipe;
        owner->handle.reset();
        luaL_error(L, "Failed to open stdin: %s", uv_strerror(openStatus));
    }
    handle->stream = pipe;

    handle->stream->data = handle.get();
    return handle.get();
}

static void allocBuffer(uv_handle_t* handle, size_t suggestedSize, uv_buf_t* buf)
{
    IOHandle* ioh = static_cast<IOHandle*>(handle->data);
    ioh->readBuf.resize(suggestedSize);
    buf->base = ioh->readBuf.data();
    buf->len = ioh->readBuf.size();
}

static void onStdinRead(uv_stream_t* stream, ssize_t nread, const uv_buf_t* buf)
{
    IOHandle* handle = static_cast<IOHandle*>(stream->data);

    if (nread > 0)
    {
        handle->lineBuffer.append(buf->base, static_cast<size_t>(nread));

        size_t pos = handle->lineBuffer.find('\n');
        if (pos != std::string::npos)
        {
            // Extract one line, stripping the trailing newline (and \r on Windows).
            std::string line = handle->lineBuffer.substr(0, pos);
            if (!line.empty() && line.back() == '\r')
                line.pop_back();

            handle->lineBuffer.erase(0, pos + 1); // keep everything after '\n'

            // Stop reading until the next io.read() call — the handle stays open.
            uv_read_stop(stream);

            handle->pendingToken->complete([line](lua_State* L) -> int {
                lua_pushlstring(L, line.data(), line.size());
                return 1;
            });
            handle->pendingToken = nullptr;
        }
        // No newline yet — keep reading.
    }
    else if (nread == 0)
    {
        // EAGAIN / nothing to read right now; libuv will call back when data arrives.
    }
    else // nread < 0: EOF or error
    {
        if (!handle->lineBuffer.empty())
        {
            // Return whatever partial data remains (last line without trailing newline).
            std::string line = std::move(handle->lineBuffer);

            if (!line.empty() && line.back() == '\n')
                line.pop_back();
            if (!line.empty() && line.back() == '\r')
                line.pop_back();

            handle->pendingToken->complete([line](lua_State* L) -> int {
                lua_pushlstring(L, line.data(), line.size());
                return 1;
            });
        }
        else
        {
            handle->pendingToken->fail(uv_strerror(static_cast<int>(nread)));
        }

        handle->pendingToken = nullptr;
        handle->owner->handle.reset(); // destructor schedules uv_close
    }
}

int read(lua_State* L)
{
    uv_loop_t* loop = getRuntimeLoop(L);
    IOHandle* handle = getStdinHandle(L, loop);

    // If `lineBuffer` already contains a complete line from a previous oversized
    // read, we can return it immediately without going back to libuv.
    size_t pos = handle->lineBuffer.find('\n');
    if (pos != std::string::npos)
    {
        std::string line = handle->lineBuffer.substr(0, pos);
        if (!line.empty() && line.back() == '\r')
            line.pop_back();

        handle->lineBuffer.erase(0, pos + 1);
        lua_pushlstring(L, line.data(), line.size());

        return 1;
    }

    handle->pendingToken = getResumeToken(L);
    uv_read_start(reinterpret_cast<uv_stream_t*>(handle->stream), allocBuffer, onStdinRead);
    return lua_yield(L, 0);
}

} // anonymous namespace

const char* const IO::properties[] = {nullptr};

const luaL_Reg IO::lib[] = {
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
