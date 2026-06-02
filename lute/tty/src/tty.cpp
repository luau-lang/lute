#include "lute/tty.h"

#include "lute/os_signal.h"
#include "lute/runtime.h"
#include "lute/userdatas.h"
#include "lute/uvstream.h"

#include "Luau/VecDeque.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include <cstring>
#include <memory>
#include <optional>

namespace
{

struct OpenOptions
{
    bool raw = false;
};

struct TTYHandle : std::enable_shared_from_this<TTYHandle>
{
    static std::shared_ptr<TTYHandle> create(lua_State* L, int fd, const OpenOptions& opts);

    TTYHandle(const TTYHandle&) = delete;
    TTYHandle& operator=(const TTYHandle&) = delete;

    void close();
    bool isClosed() const
    {
        return closeRequested;
    }

    std::optional<std::string> popChunk();
    bool atEof() const
    {
        return eof;
    }
    bool hasPendingRead() const
    {
        return bool(pendingRead);
    }

    uv_stream_t* writeStream()
    {
        return stream->getStream();
    }

    bool hasResizeListener() const
    {
        return listener != nullptr;
    }
    void setResizeListener(std::shared_ptr<Ref> cb)
    {
        listener = std::move(cb);
    }

    void beginRead(ResumeToken token);
    void dispatchResize();

private:
    TTYHandle(lua_State* L, int fd)
        : runtime(getRuntime(L))
        , stream(std::make_unique<uvutils::TTYStream>(runtime->getEventLoop(), fd, "tty"))
    {
    }

    void startReading();
    void installWindowChangeHandler();

    Runtime* runtime;
    std::unique_ptr<uvutils::TTYStream> stream;
    std::unique_ptr<process::SignalHandle> windowChangeHandler;
    std::shared_ptr<Ref> listener;

    Luau::VecDeque<std::string> chunks;
    ResumeToken pendingRead;

    bool reading = false;
    bool eof = false;
    bool closeRequested = false;
};

void TTYHandle::installWindowChangeHandler()
{
    int signum = -1;
#ifdef SIGWINCH
    signum = SIGWINCH;
#endif
    TTYHandle* raw = this;
    windowChangeHandler = std::make_unique<process::SignalHandle>(
        runtime->getEventLoop(),
        signum,
        [raw]()
        {
            raw->dispatchResize();
        }
    );
}

std::shared_ptr<TTYHandle> TTYHandle::create(lua_State* L, int fd, const OpenOptions& opts)
{
    if (uv_guess_handle(fd) != UV_TTY)
        luaL_errorL(L, "fd %d is not a TTY", fd);

    // Constructor runs uv_tty_init via TTYStream.
    std::shared_ptr<TTYHandle> handle(new TTYHandle(L, fd));

    if (opts.raw)
    {
        int rc = uv_tty_set_mode(handle->stream->stream.get(), UV_TTY_MODE_RAW);
        if (rc < 0)
        {
            handle->close();
            luaL_errorL(L, "uv_tty_set_mode failed: %s", uv_strerror(rc));
        }
    }

    handle->installWindowChangeHandler();

    return handle;
}

struct WriteRequest
{
    uv_write_t req;
    std::shared_ptr<TTYHandle> handle;
    std::string data;
    uv_buf_t buf;
};

std::optional<std::string> TTYHandle::popChunk()
{
    if (chunks.empty())
        return std::nullopt;
    std::string chunk = std::move(chunks.front());
    chunks.pop_front();
    return chunk;
}

void TTYHandle::beginRead(ResumeToken token)
{
    startReading();
    pendingRead = std::move(token);
}

void TTYHandle::close()
{
    if (closeRequested)
        return;
    closeRequested = true;
    eof = true;

    if (pendingRead && !pendingRead->completed)
    {
        ResumeToken token = std::move(pendingRead);
        token->complete(
            [](lua_State* L) -> int
            {
                lua_pushnil(L);
                return 1;
            }
        );
    }
    pendingRead.reset();

    windowChangeHandler.reset();
    listener.reset();

    if (stream && !stream->isClosed())
    {
        stream->close([keepAlive = shared_from_this()]() {});
    }
}

static TTYHandle* checkTTY(lua_State* L, int idx)
{
    auto* p = static_cast<std::shared_ptr<TTYHandle>*>(lua_touserdatatagged(L, idx, kTtyHandleTag));
    if (!p || !*p)
        luaL_typeerrorL(L, idx, "TTY");
    return p->get();
}

void TTYHandle::startReading()
{
    if (reading || !stream || stream->isClosed())
        return;

    reading = true;
    TTYHandle* h = this;
    stream->read(
        [h](std::string_view input)
        {
            std::string chunk(input);
            if (h->pendingRead && !h->pendingRead->completed)
            {
                ResumeToken token = std::move(h->pendingRead);
                token->complete(
                    [c = std::move(chunk)](lua_State* L) -> int
                    {
                        lua_pushlstring(L, c.data(), c.size());
                        return 1;
                    }
                );
            }
            else
            {
                h->chunks.push_back(std::move(chunk));
            }
        },
        [h](std::optional<std::string> err)
        {
            h->eof = true;
            h->reading = false;
            if (h->pendingRead && !h->pendingRead->completed)
            {
                ResumeToken token = std::move(h->pendingRead);
                if (err)
                    token->fail(*err);
                else
                    token->complete(
                        [](lua_State* L) -> int
                        {
                            lua_pushnil(L);
                            return 1;
                        }
                    );
            }
        }
    );
}

static int ttyRead(lua_State* L)
{
    TTYHandle* handle = checkTTY(L, 1);

    if (handle->isClosed())
        luaL_errorL(L, "tty is closed");

    if (auto chunk = handle->popChunk())
    {
        lua_pushlstring(L, chunk->data(), chunk->size());
        return 1;
    }

    if (handle->atEof())
    {
        lua_pushnil(L);
        return 1;
    }

    if (handle->hasPendingRead())
        luaL_errorL(L, "tty:read already pending");

    handle->beginRead(getResumeToken(L));
    return lua_yield(L, 0);
}

static int ttyWrite(lua_State* L)
{
    TTYHandle* handle = checkTTY(L, 1);

    if (handle->isClosed())
        luaL_errorL(L, "tty is closed");

    size_t len = 0;
    const char* data = luaL_checklstring(L, 2, &len);

    if (len == 0)
        return 0;

    auto* w = new WriteRequest();
    w->data.assign(data, len);
    w->buf = uv_buf_init(w->data.data(), unsigned(w->data.size()));
    w->req.data = w;
    w->handle = handle->shared_from_this();

    int rc = uv_write(
        &w->req,
        handle->writeStream(),
        &w->buf,
        1,
        [](uv_write_t* req, int status)
        {
            auto* w = static_cast<WriteRequest*>(req->data);
            delete w;
        }
    );
    if (rc < 0)
    {
        delete w;
        luaL_errorL(L, "uv_write failed: %s", uv_strerror(rc));
    }
    return 0;
}

static int ttyClose(lua_State* L)
{
    TTYHandle* handle = checkTTY(L, 1);
    handle->close();
    return 0;
}

void TTYHandle::dispatchResize()
{
    if (!listener || !stream || stream->isClosed())
        return;

    int width = 0;
    int height = 0;
    uv_tty_get_winsize(stream->stream.get(), &width, &height);

    runtime->scheduleLuauCallback(
        listener,
        [height, width](lua_State* L) -> int
        {
            lua_checkstack(L, 2);
            lua_createtable(L, 0, 2);
            lua_pushinteger(L, height);
            lua_setfield(L, -2, "rows");
            lua_pushinteger(L, width);
            lua_setfield(L, -2, "cols");
            return 1;
        }
    );
}

static int ttyOnResize(lua_State* L)
{
    TTYHandle* handle = checkTTY(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);

    if (handle->isClosed())
        luaL_errorL(L, "tty is closed");

    if (handle->hasResizeListener())
        luaL_errorL(L, "tty:onResize listener already registered");

    handle->setResizeListener(std::make_shared<Ref>(L, 2));
    return 0;
}

static int ttyOpen(lua_State* L)
{
    int fd = int(luaL_checkinteger(L, 1));

    OpenOptions opts;
    if (lua_istable(L, 2))
    {
        lua_getfield(L, 2, "raw");
        if (!lua_isnil(L, -1))
            opts.raw = lua_toboolean(L, -1);
        lua_pop(L, 1);
    }

    auto handle = TTYHandle::create(L, fd, opts);

    void* storage = lua_newuserdatataggedwithmetatable(L, sizeof(std::shared_ptr<TTYHandle>), kTtyHandleTag);
    new (storage) std::shared_ptr<TTYHandle>(std::move(handle));

    return 1;
}

static void registerTTYMetatable(lua_State* L)
{
    luaL_newmetatable(L, "TTY");

    lua_pushcfunction(
        L,
        [](lua_State* L) -> int
        {
            const char* key = luaL_checkstring(L, 2);
            if (strcmp(key, "read") == 0)
            {
                lua_pushcfunction(L, ttyRead, "TTY.read");
                return 1;
            }
            if (strcmp(key, "write") == 0)
            {
                lua_pushcfunction(L, ttyWrite, "TTY.write");
                return 1;
            }
            if (strcmp(key, "close") == 0)
            {
                lua_pushcfunction(L, ttyClose, "TTY.close");
                return 1;
            }
            if (strcmp(key, "onResize") == 0)
            {
                lua_pushcfunction(L, ttyOnResize, "TTY.onResize");
                return 1;
            }
            return 0;
        },
        "TTY.__index"
    );
    lua_setfield(L, -2, "__index");

    lua_pushstring(L, "TTY");
    lua_setfield(L, -2, "__type");

    lua_setuserdatadtor(
        L,
        kTtyHandleTag,
        [](lua_State* L, void* ud)
        {
            auto* p = static_cast<std::shared_ptr<TTYHandle>*>(ud);
            if (*p)
                (*p)->close();
            std::destroy_at(p);
        }
    );
    lua_setuserdatametatable(L, kTtyHandleTag);
}

} // namespace

const char* const TTY::properties[] = {nullptr};

const luaL_Reg TTY::lib[] = {
    {"open", ttyOpen},
    {nullptr, nullptr},
};

int TTY::pushLibrary(lua_State* L)
{
    registerTTYMetatable(L);

    lua_createtable(L, 0, std::size(TTY::lib));
    for (auto& [name, func] : TTY::lib)
    {
        if (!name || !func)
            break;
        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }
    lua_setreadonly(L, -1, 1);
    return 1;
}

LUTE_API int luaopen_tty(lua_State* L)
{
    return TTY::openAsGlobal(L);
}

LUTE_API int luteopen_tty(lua_State* L)
{
    return TTY::pushLibrary(L);
}
