#include "lute/runtime.h"
#include "lute/userdatas.h"

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

#include "system_ca.h"
#include "wscommon.h"

namespace net::client
{
struct WebSocketConnection;
struct WebSocketHandle;

struct PendingSend
{
    std::string payload;
    bool binary = false;
    size_t offset = 0;
};

struct WebSocketPollState
{
    uv_poll_t handle{};
    std::shared_ptr<WebSocketConnection> owner;
};

static void clearWebSocketPollState(WebSocketPollState*& pollState, int& activePollEvents)
{
    if (!pollState)
        return;

    WebSocketPollState* state = pollState;
    pollState = nullptr;
    activePollEvents = 0;

    uv_poll_stop(&state->handle);
    uv_close(
        reinterpret_cast<uv_handle_t*>(&state->handle),
        [](uv_handle_t* handle)
        {
            delete static_cast<WebSocketPollState*>(handle->data);
        }
    );
}

static void pushWebSocketMessageToLua(lua_State* L, const std::string& message, bool binary)
{
    if (binary)
    {
        void* buffer = lua_newbuffer(L, message.size());
        if (!message.empty())
            memcpy(buffer, message.data(), message.size());
        return;
    }

    lua_pushlstring(L, message.data(), message.size());
}

static std::pair<int, std::string> parseClosePayload(const std::string& payload)
{
    int closeCode = 1000;
    std::string closeReason;

    if (payload.size() >= 2)
    {
        const unsigned char* bytes = reinterpret_cast<const unsigned char*>(payload.data());
        closeCode = int((bytes[0] << 8) | bytes[1]);
        if (payload.size() > 2)
            closeReason.assign(payload.data() + 2, payload.size() - 2);
    }

    return {closeCode, std::move(closeReason)};
}

struct WebSocketConnection : std::enable_shared_from_this<WebSocketConnection>
{
    CURL* curl = nullptr;
    curl_slist* headerList = nullptr;
    WebSocketPollState* pollState = nullptr;
    std::mutex curlMutex;
    int activePollEvents = 0;
    std::vector<char> recvBuffer = std::vector<char>(16 * 1024);
    std::string currentMessage;
    bool currentBinary = false;
    bool hasCurrentMessage = false;
    std::string closePayload;
    Luau::VecDeque<PendingSend> pendingSends;
    std::atomic<bool> isClosed{false};
    std::weak_ptr<WebSocketHandle> owner;
    std::shared_ptr<WebSocketHandle> keepAliveHandle;

    void setOwner(const std::shared_ptr<WebSocketHandle>& handle)
    {
        owner = handle;
        keepAliveHandle = handle;
    }

    void releaseKeepAliveHandle()
    {
        keepAliveHandle.reset();
    }

    bool closed() const
    {
        return isClosed.load();
    }

    bool startPolling(Runtime* runtime, curl_socket_t socket)
    {
        if (!runtime || socket == CURL_SOCKET_BAD)
            return false;

        auto* state = new WebSocketPollState();
        state->owner = shared_from_this();
        state->handle.data = state;

        int initResult = uv_poll_init_socket(runtime->getEventLoop(), &state->handle, socket);
        if (initResult != 0)
        {
            delete state;
            return false;
        }

        pollState = state;

        if (!updatePollingInterest())
        {
            closeTransport(false);
            return false;
        }

        return true;
    }

    bool applyPollingEvents(int events)
    {
        if (!pollState)
            return false;

        if (activePollEvents == events)
            return true;

        int startResult = uv_poll_start(
            &pollState->handle,
            events,
            [](uv_poll_t* handle, int status, int events)
            {
                auto* state = static_cast<WebSocketPollState*>(handle->data);
                if (!state || !state->owner)
                    return;

                state->owner->handlePollEvent(status, events);
            }
        );

        if (startResult != 0)
            return false;

        activePollEvents = events;
        return true;
    }

    bool updatePollingInterest()
    {
        int events = UV_READABLE;
        if (!pendingSends.empty())
            events |= UV_WRITABLE;

        return applyPollingEvents(events);
    }

    void handlePollEvent(int status, int events)
    {
        if (status < 0)
        {
            closeWithError(uv_strerror(status));
            return;
        }

        if (events & UV_READABLE)
            processIncoming();

        if (!closed() && (events & UV_WRITABLE))
            flushOutgoing();
    }

    void enqueueSend(std::string payload, bool binary)
    {
        if (closed())
            return;

        pendingSends.push_back({std::move(payload), binary, 0});
        flushOutgoing();
    }

    bool closeTransport(bool sendCloseFrame)
    {
        bool expected = false;
        if (!isClosed.compare_exchange_strong(expected, true))
            return false;

        clearWebSocketPollState(pollState, activePollEvents);
        pendingSends.clear();
        currentMessage.clear();
        hasCurrentMessage = false;
        closePayload.clear();

        {
            std::lock_guard<std::mutex> lock(curlMutex);
            if (curl)
            {
                if (sendCloseFrame)
                {
                    size_t sent = 0;
                    (void)curl_ws_send(curl, "", 0, &sent, 0, CURLWS_CLOSE);
                }

                curl_easy_cleanup(curl);
                curl = nullptr;
            }

            if (headerList)
            {
                curl_slist_free_all(headerList);
                headerList = nullptr;
            }
        }

        return true;
    }

    void closeWithCode(int closeCode = 1000, std::string closeReason = "", bool sendCloseFrame = true)
    {
        if (!closeTransport(sendCloseFrame))
            return;

        notifyClose(closeCode, std::move(closeReason));
    }

    void closeWithError(std::string error)
    {
        if (!closeTransport(false))
            return;

        notifyError(std::move(error));
        notifyClose(1006, "");
    }

    void processIncoming()
    {
        while (!closed())
        {
            size_t receivedLength = 0;
            const curl_ws_frame* meta = nullptr;
            CURLcode result = CURLE_OK;

            {
                std::lock_guard<std::mutex> lock(curlMutex);
                if (!curl)
                    return;

                result = curl_ws_recv(curl, recvBuffer.data(), recvBuffer.size(), &receivedLength, &meta);
            }

            if (closed())
                return;

            if (result == CURLE_AGAIN)
                return;

            if (result != CURLE_OK)
            {
                closeWithError(curl_easy_strerror(result));
                return;
            }

            if (!meta)
                continue;

            if (meta->flags & CURLWS_CLOSE)
            {
                closePayload.append(recvBuffer.data(), receivedLength);

                if (meta->bytesleft != 0)
                    continue;

                auto [closeCode, closeReason] = parseClosePayload(closePayload);
                closeWithCode(closeCode, std::move(closeReason));
                return;
            }

            if (meta->flags & CURLWS_PING)
            {
                size_t sent = 0;
                std::lock_guard<std::mutex> lock(curlMutex);
                if (curl)
                    (void)curl_ws_send(curl, recvBuffer.data(), receivedLength, &sent, 0, CURLWS_PONG);
                continue;
            }

            if (meta->flags & (CURLWS_TEXT | CURLWS_BINARY | CURLWS_CONT))
            {
                if (meta->flags & (CURLWS_TEXT | CURLWS_BINARY))
                {
                    bool binary = (meta->flags & CURLWS_BINARY) != 0;
                    if (!hasCurrentMessage)
                    {
                        currentMessage.clear();
                        currentBinary = binary;
                        hasCurrentMessage = true;
                    }
                    else if (currentBinary != binary)
                    {
                        closeWithError("websocket received mixed message types");
                        return;
                    }
                }
                else if (!hasCurrentMessage)
                {
                    currentMessage.clear();
                    currentBinary = false;
                    hasCurrentMessage = true;
                }

                currentMessage.append(recvBuffer.data(), receivedLength);

                if (meta->bytesleft == 0 && !(meta->flags & CURLWS_CONT))
                {
                    std::string message = std::move(currentMessage);
                    bool binary = currentBinary;
                    hasCurrentMessage = false;

                    notifyMessage(std::move(message), binary);
                }
            }
        }
    }

    void flushOutgoing()
    {
        while (!pendingSends.empty() && !closed())
        {
            PendingSend& pending = pendingSends.front();
            size_t sent = 0;
            CURLcode result = CURLE_OK;

            {
                std::lock_guard<std::mutex> lock(curlMutex);
                if (!curl)
                {
                    pendingSends.clear();
                    return;
                }

                size_t remaining = pending.payload.size() - pending.offset;
                const char* data = remaining > 0 ? pending.payload.data() + pending.offset : pending.payload.data();

                result = curl_ws_send(curl, data, remaining, &sent, 0, pending.binary ? CURLWS_BINARY : CURLWS_TEXT);
            }

            if (result == CURLE_AGAIN)
                break;

            if (result != CURLE_OK)
            {
                closeWithError("websocket send failed: " + std::string(curl_easy_strerror(result)));
                return;
            }

            pending.offset += sent;

            if (pending.payload.empty() || pending.offset >= pending.payload.size())
            {
                pendingSends.pop_front();
                continue;
            }

            if (sent == 0)
                break;
        }

        if (!closed() && !updatePollingInterest())
            closeWithError("failed to update websocket polling");
    }

    ~WebSocketConnection()
    {
        closeTransport(false);
    }

    void notifyMessage(std::string message, bool binary);
    void notifyClose(int closeCode, std::string closeReason);
    void notifyError(std::string error);
};

struct WebSocketHandle : std::enable_shared_from_this<WebSocketHandle>
{
    Runtime* runtime = nullptr;
    std::shared_ptr<Ref> onOpenRef;
    std::shared_ptr<Ref> onMessageRef;
    std::shared_ptr<Ref> onCloseRef;
    std::shared_ptr<Ref> onErrorRef;
    std::weak_ptr<WebSocketConnection> connection;
    std::atomic<bool> hasScheduledClose{false};
    bool isActive = false;

    std::shared_ptr<WebSocketConnection> lockConnection() const
    {
        return connection.lock();
    }

    void attachConnection(const std::shared_ptr<WebSocketConnection>& newConnection)
    {
        connection = newConnection;
        newConnection->setOwner(shared_from_this());
    }

    void activate()
    {
        isActive = true;
    }

    bool closed() const
    {
        auto lockedConnection = lockConnection();
        return !lockedConnection || lockedConnection->closed();
    }

    void scheduleCallback(const std::shared_ptr<Ref>& callback, std::function<int(lua_State*)> argPusher)
    {
        if (!isActive || !callback || !runtime)
            return;

        runtime->scheduleLuauCallback(callback, std::move(argPusher));
    }

    void scheduleCloseCallback(int closeCode = 1000, std::string closeReason = "")
    {
        bool expected = false;
        if (!isActive || !hasScheduledClose.compare_exchange_strong(expected, true))
            return;

        scheduleCallback(
            onCloseRef,
            [closeCode, closeReason = std::move(closeReason)](lua_State* L)
            {
                lua_pushinteger(L, closeCode);
                lua_pushlstring(L, closeReason.data(), closeReason.size());
                return 2;
            }
        );
    }

    void handleMessage(std::string message, bool binary)
    {
        scheduleCallback(
            onMessageRef,
            [message = std::move(message), binary](lua_State* L)
            {
                pushWebSocketMessageToLua(L, message, binary);
                return 1;
            }
        );
    }

    void handleClose(int closeCode, std::string closeReason)
    {
        scheduleCloseCallback(closeCode, std::move(closeReason));
        releaseConnectionKeepAlive();
    }

    void releaseConnectionKeepAlive()
    {
        if (auto lockedConnection = lockConnection())
            lockedConnection->releaseKeepAliveHandle();
    }

    void handleError(std::string error)
    {
        scheduleErrorCallback(std::move(error));
        scheduleCloseCallback(1006);
        releaseConnectionKeepAlive();
    }

    void scheduleErrorCallback(std::string error)
    {
        scheduleCallback(
            onErrorRef,
            [error = std::move(error)](lua_State* L)
            {
                lua_pushlstring(L, error.data(), error.size());
                return 1;
            }
        );
    }

    void notifyOpen()
    {
        scheduleCallback(
            onOpenRef,
            [](lua_State*)
            {
                return 0;
            }
        );
    }

    void send(std::string payload, bool binary)
    {
        if (auto lockedConnection = lockConnection())
            lockedConnection->enqueueSend(std::move(payload), binary);
    }

    void close()
    {
        closeWithCode();
    }

    void closeWithCode(int closeCode = 1000, std::string closeReason = "", bool sendCloseFrame = true)
    {
        if (!isActive)
        {
            if (auto lockedConnection = lockConnection())
            {
                lockedConnection->closeTransport(false);
                lockedConnection->releaseKeepAliveHandle();
            }
            return;
        }

        scheduleCloseCallback(closeCode, std::move(closeReason));

        if (auto lockedConnection = lockConnection())
        {
            lockedConnection->closeTransport(sendCloseFrame);
            lockedConnection->releaseKeepAliveHandle();
        }

        releaseConnectionKeepAlive();
    }

    ~WebSocketHandle()
    {
        close();

        onOpenRef.reset();
        onMessageRef.reset();
        onCloseRef.reset();
        onErrorRef.reset();
    }
};

void WebSocketConnection::notifyMessage(std::string message, bool binary)
{
    if (auto handle = owner.lock())
        handle->handleMessage(std::move(message), binary);
}

void WebSocketConnection::notifyClose(int closeCode, std::string closeReason)
{
    if (auto handle = owner.lock())
        handle->handleClose(closeCode, std::move(closeReason));
}

void WebSocketConnection::notifyError(std::string error)
{
    if (auto handle = owner.lock())
        handle->handleError(std::move(error));
}

static std::shared_ptr<WebSocketHandle>* getWebSocketHandle(lua_State* L, int index)
{
    return static_cast<std::shared_ptr<WebSocketHandle>*>(lua_touserdatatagged(L, index, kWebSocketHandleTag));
}

int ws_send(lua_State* L)
{
    if (lua_gettop(L) != 2)
        luaL_errorL(L, "websocket send expects exactly 1 payload argument");

    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handleStorage = getWebSocketHandle(L, 1);
    if (!handleStorage || !(*handleStorage) || (*handleStorage)->closed())
        luaL_errorL(L, "Invalid or closed websocket");

    WebSocketPayload payload = extractWebSocketPayload(L, 2);
    (*handleStorage)->send(std::string(payload.data, payload.length), payload.binary);
    return 0;
}

int ws_close(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handleStorage = getWebSocketHandle(L, 1);
    if (!handleStorage || !(*handleStorage))
        luaL_errorL(L, "Invalid websocket");

    (*handleStorage)->close();
    return 0;
}

int websocket(lua_State* L)
{
    std::string url = luaL_checkstring(L, 1);
    std::vector<std::pair<std::string, std::string>> headers;
    std::shared_ptr<Ref> onOpenRef;
    std::shared_ptr<Ref> onMessageRef;
    std::shared_ptr<Ref> onCloseRef;
    std::shared_ptr<Ref> onErrorRef;

    if (lua_istable(L, 2))
    {
        lua_getfield(L, 2, "headers");
        if (lua_istable(L, -1))
        {
            lua_pushnil(L);
            while (lua_next(L, -2))
            {
                if (lua_isstring(L, -2) && lua_isstring(L, -1))
                    headers.emplace_back(lua_tostring(L, -2), lua_tostring(L, -1));

                lua_pop(L, 1);
            }
        }
        lua_pop(L, 1);

        lua_getfield(L, 2, "onopen");
        if (lua_isfunction(L, -1))
            onOpenRef = std::make_shared<Ref>(L, -1);
        lua_pop(L, 1);

        lua_getfield(L, 2, "onmessage");
        if (lua_isfunction(L, -1))
            onMessageRef = std::make_shared<Ref>(L, -1);
        lua_pop(L, 1);

        lua_getfield(L, 2, "onclose");
        if (lua_isfunction(L, -1))
            onCloseRef = std::make_shared<Ref>(L, -1);
        lua_pop(L, 1);

        lua_getfield(L, 2, "onerror");
        if (lua_isfunction(L, -1))
            onErrorRef = std::make_shared<Ref>(L, -1);
        lua_pop(L, 1);
    }

    auto token = getResumeToken(L);
    Runtime* runtime = token->runtime;

    runtime->runInWorkQueue(
        [token,
         runtime,
         url = std::move(url),
         headers = std::move(headers),
         onOpenRef = std::move(onOpenRef),
         onMessageRef = std::move(onMessageRef),
         onCloseRef = std::move(onCloseRef),
         onErrorRef = std::move(onErrorRef)]() mutable
        {
            CURL* curl = curl_easy_init();
            if (!curl)
            {
                token->fail("failed to initialize websocket");
                return;
            }

            curl_slist* headerList = nullptr;

            curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
            net::applySystemCA(curl);
            curl_easy_setopt(curl, CURLOPT_CONNECT_ONLY, 2L);

            for (const auto& headerPair : headers)
            {
                std::string headerString = headerPair.first + ": " + headerPair.second;
                headerList = curl_slist_append(headerList, headerString.c_str());
            }

            if (headerList)
                curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headerList);

            CURLcode result = curl_easy_perform(curl);
            if (result != CURLE_OK)
            {
                std::string error = curl_easy_strerror(result);
                if (headerList)
                    curl_slist_free_all(headerList);
                curl_easy_cleanup(curl);
                token->fail("websocket connect failed: " + error);
                return;
            }

            curl_socket_t socket = CURL_SOCKET_BAD;
            if (curl_easy_getinfo(curl, CURLINFO_ACTIVESOCKET, &socket) != CURLE_OK || socket == CURL_SOCKET_BAD)
            {
                if (headerList)
                    curl_slist_free_all(headerList);
                curl_easy_cleanup(curl);
                token->fail("failed to get websocket socket");
                return;
            }

            token->complete(
                [runtime,
                 curl,
                 socket,
                 headerList,
                 onOpenRef = std::move(onOpenRef),
                 onMessageRef = std::move(onMessageRef),
                 onCloseRef = std::move(onCloseRef),
                 onErrorRef = std::move(onErrorRef)](lua_State* L) mutable
                {
                    auto connection = std::make_shared<WebSocketConnection>();
                    connection->curl = curl;
                    connection->headerList = headerList;

                    auto handle = std::make_shared<WebSocketHandle>();
                    handle->runtime = runtime;
                    handle->onOpenRef = std::move(onOpenRef);
                    handle->onMessageRef = std::move(onMessageRef);
                    handle->onCloseRef = std::move(onCloseRef);
                    handle->onErrorRef = std::move(onErrorRef);
                    handle->attachConnection(connection);

                    if (!connection->startPolling(runtime, socket))
                    {
                        connection->closeTransport(false);
                        connection->releaseKeepAliveHandle();
                        luaL_errorL(L, "failed to initialize websocket polling");
                    }

                    handle->activate();

                    auto* storage = new (static_cast<std::shared_ptr<WebSocketHandle>*>(
                        lua_newuserdatataggedwithmetatable(L, sizeof(std::shared_ptr<WebSocketHandle>), kWebSocketHandleTag)
                    )) std::shared_ptr<WebSocketHandle>(handle);
                    (void)storage;

                    handle->notifyOpen();
                    return 1;
                }
            );
        }
    );

    return lua_yield(L, 0);
}
} // namespace net::client
