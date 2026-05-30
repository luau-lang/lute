#include "lute/runtime.h"
#include "lute/userdatas.h"
#include "lute/uvstream.h"

#include "Luau/VecDeque.h"

#include "lua.h"
#include "lualib.h"

#include "curl/curl.h"
#include "curl/websockets.h"

#include <atomic>
#include <cstring>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <utility>
#include <vector>
#include <optional>

#include "system_ca.h"
#include "wscommon.h"

namespace net::client
{
struct TCPStreamHandle;

struct TCPOptions
{
    std::string host;
    int port;
};

struct ReadWaiter {
    ResumeToken token;
    size_t amount;
};

struct TCPStreamHandle
{
    uv_loop_t *loop;
    ResumeToken token;
    TCPOptions options;
    std::unique_ptr<uvutils::TCPStream> stream;
    std::vector<ReadWaiter> readWaiters;
    std::vector<char> readBuffer;
    bool isActive = false;
    std::optional<std::string> pendingError;

    TCPStreamHandle(lua_State* L, TCPOptions options)
        : loop(getRuntimeLoop(L)), token(getResumeToken(L)), options(options)
    {
        stream = std::make_unique<uvutils::TCPStream>(loop, "TCPStreamHandle");
    }

    void beginRead() {
        stream->read(
            [this](std::string_view data)
            {
                readBuffer.insert(readBuffer.end(), data.begin(), data.end());
                while (!readWaiters.empty() && (readWaiters.front().amount == SIZE_MAX || readWaiters.front().amount <= readBuffer.size()))
                {
                    auto& waiter = readWaiters.front();
                    auto amount = waiter.amount == SIZE_MAX ? readBuffer.size() : waiter.amount;
                    std::vector<char> buf(readBuffer.begin(), readBuffer.begin() + amount);
                    readBuffer.erase(readBuffer.begin(), readBuffer.begin() + amount);

                    waiter.token->complete(
                        [buf = std::move(buf)](lua_State* L)
                        {
                            void* luaData = lua_newbuffer(L, buf.size());
                            std::memcpy(luaData, buf.data(), buf.size());
                            return 1;
                        }
                    );

                    readWaiters.erase(readWaiters.begin());
                }
            },
            [this](std::optional<std::string> error)
            {
                if (error) {
                    pendingError = error;
                }
            }
        );
    }

    bool connect()
    {
        struct sockaddr_in dest;
        if (uv_ip4_addr(options.host.c_str(), options.port, &dest) != 0)
        {
            token->fail("Invalid IP address or port");
            return false;
        }

        uv_connect_t* connectReq = new uv_connect_t;
        connectReq->data = this;

        isActive = true;

        int result = uv_tcp_connect(connectReq, stream->stream.get(), (const struct sockaddr*)&dest,
            [](uv_connect_t* req, int status)
            {
                auto* handle = static_cast<TCPStreamHandle*>(req->data);
                delete req;

                if (status < 0)
                {
                    std::string error = "Connection failed: " + std::string(uv_strerror(status));
                    handle->token->fail(error);
                    return;
                }

                handle->beginRead();

                handle->token->complete(
                    [handle](lua_State* L)
                    {
                        auto* storage = new (static_cast<std::shared_ptr<TCPStreamHandle>*>(
                            lua_newuserdatataggedwithmetatable(L, sizeof(std::shared_ptr<TCPStreamHandle>), kTCPStreamHandleTag)
                        )) std::shared_ptr<TCPStreamHandle>(handle);
                        (void)storage;

                        return 1;
                    }
                );
            }
        );

        if (result < 0)
        {
            std::string error = "Connection initiation failed: " + std::string(uv_strerror(result));
            token->fail(error);
            return false;
        }

        return true;
    }

    void close(std::function<void()> onClose = [](){})
    {
        if (stream && !stream->closed)
        {
            stream->close(
                [this, onClose]()
                {
                    if (!pendingError)
                        pendingError = "Connection closed";

                    for (auto& waiter : readWaiters)
                    {
                        waiter.token->fail(*pendingError);
                    }
                    readWaiters.clear();

                    onClose();
                }
            );
        }
    }

    ~TCPStreamHandle()
    {
        close();
    }
};

std::shared_ptr<TCPStreamHandle>* getTCPStreamHandle(lua_State* L, int index)
{
    return static_cast<std::shared_ptr<TCPStreamHandle>*>(lua_touserdatatagged(L, index, kTCPStreamHandleTag));
}

int tcp_read(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handleStorage = getTCPStreamHandle(L, 1);
    if (!handleStorage || !(*handleStorage) || (*handleStorage)->pendingError)
    {
        std::string error = "";
        if (handleStorage && *handleStorage && (*handleStorage)->pendingError)
            error += ": " + (*handleStorage)->pendingError.value();
        luaL_error(L, "Invalid or closed TCP connection: %s", error.c_str());
        return 0;
    }

    TCPStreamHandle* handle = (*handleStorage).get();

    int _amount = luaL_optinteger(L, 2, -1);
    size_t amount = _amount < 0 ? SIZE_MAX : static_cast<size_t>(_amount);
    
    if (amount <= handle->readBuffer.size()) {
        void* data = lua_newbuffer(L, amount);
        std::memcpy(data, handle->readBuffer.data(), amount);
        handle->readBuffer.erase(handle->readBuffer.begin(), handle->readBuffer.begin() + amount);
        return 1;
    }
    else {
        ResumeToken readToken = getResumeToken(L);
        handle->readWaiters.push_back({readToken, amount});
        return lua_yield(L, 0);
    }
}

int tcp_write(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handleStorage = getTCPStreamHandle(L, 1);
    if (!handleStorage || !(*handleStorage) || (*handleStorage)->pendingError)
    {
        std::string error = "";
        if (handleStorage && *handleStorage && (*handleStorage)->pendingError)
            error += ": " + (*handleStorage)->pendingError.value();
        luaL_error(L, "Invalid or closed TCP connection: %s", error.c_str());
    }

    size_t dataLen;
    void* data;

    if (lua_isstring(L, 2))
    {
        data = (void*)lua_tolstring(L, 2, &dataLen);
    }
    else if (lua_isbuffer(L, 2))
    {
        data = luaL_checkbuffer(L, 2, &dataLen);
    } else {
        luaL_error(L, "Data must be a string or buffer");
        return 0;
    }

    TCPStreamHandle* handle = (*handleStorage).get();

    handle->stream->write(data, dataLen,
        [token = getResumeToken(L)](std::optional<std::string> error)
        {
            if (error)
                token->fail(*error);
            else
                token->complete([](lua_State* L) { return 0; });
        }
    );

    return lua_yield(L, 0);
}

int tcp_close(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handleStorage = getTCPStreamHandle(L, 1);
    if (!handleStorage || !(*handleStorage))
        luaL_error(L, "Invalid TCP connection");
    if ((*handleStorage)->stream->closed)
        luaL_error(L, "TCP connection already closed");

    ResumeToken token = getResumeToken(L);

    (*handleStorage)->close(
        [token = std::move(token)]()
        {
            token->complete([](lua_State* L) { return 0; });
        }
    );

    return lua_yield(L, 0);
}

int connect(lua_State* L)
{
    std::string host = luaL_checkstring(L, 1);
    int port = luaL_optinteger(L, 2, -1);
    if (port < 0 || port > 65535)
        luaL_error(L, "Invalid port number");
    
    TCPOptions options{std::move(host), port};
    auto* handle = new TCPStreamHandle(L, options);
    if (!handle->connect())
    {
        delete handle;
        return 0; // token->fail has already been called with the error
    }
    
    return lua_yield(L, 0);
}
} // namespace net::client
