#include "lute/net.h"

#include "lute/common.h"
#include "lute/runtime.h"
#include "lute/userdatas.h"

#include "Luau/DenseHash.h"
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

namespace net::client
{
struct WebSocketHandle;
int ws_send(lua_State* L);
int ws_close(lua_State* L);
}

namespace
{
struct CurlHolder
{
    CurlHolder()
    {
        curl_global_init(CURL_GLOBAL_DEFAULT);
    }

    ~CurlHolder()
    {
        curl_global_cleanup();
    }
};

static CurlHolder& globalCurlInit()
{
    static CurlHolder holder;
    return holder;
}

static void initializeNetClient(lua_State* L)
{
    luaL_newmetatable(L, "WebSocketHandle");

    lua_pushcfunction(
        L,
        [](lua_State* L)
        {
            const char* index = luaL_checkstring(L, -1);

            if (strcmp(index, "send") == 0)
            {
                lua_pushcfunction(L, net::client::ws_send, "WebSocketHandle.send");
                return 1;
            }

            if (strcmp(index, "close") == 0)
            {
                lua_pushcfunction(L, net::client::ws_close, "WebSocketHandle.close");
                return 1;
            }

            return 0;
        },
        "WebSocketHandle.__index"
    );
    lua_setfield(L, -2, "__index");

    lua_pushstring(L, "WebSocketHandle");
    lua_setfield(L, -2, "__type");

    lua_setuserdatadtor(
        L,
        kWebSocketHandleTag,
        [](lua_State*, void* ud)
        {
            std::destroy_at(static_cast<std::shared_ptr<net::client::WebSocketHandle>*>(ud));
        }
    );

    lua_setuserdatametatable(L, kWebSocketHandleTag);
}

} // namespace

namespace net::client
{

static const std::string kEmptyHeaderKey = "";

struct WebSocketPayload
{
    const char* data = nullptr;
    size_t length = 0;
    bool binary = false;
};

struct WebSocketPollState
{
    uv_poll_t handle{};
    std::shared_ptr<WebSocketHandle> owner;
};

struct PendingSend
{
    std::shared_ptr<std::string> payload;
    bool binary = false;
    size_t offset = 0;
    ResumeToken token;
};

struct CurlResponse
{
    std::string error;
    std::vector<char> body;
    Luau::DenseHashMap<std::string, std::string> headers;
    long status = 0;

    CurlResponse()
        : headers(kEmptyHeaderKey)
    {
    }
};

static WebSocketPayload extractWebSocketPayload(lua_State* L, int index)
{
    if (lua_isstring(L, index))
    {
        size_t length = 0;
        const char* data = lua_tolstring(L, index, &length);
        return {data, length, false};
    }

    if (lua_isbuffer(L, index))
    {
        size_t length = 0;
        void* data = lua_tobuffer(L, index, &length);
        return {static_cast<const char*>(data), length, true};
    }

    luaL_typeerrorL(L, index, "string or buffer");
}

static size_t writeFunction(char* ptr, size_t size, size_t nmemb, void* userdata)
{
    std::vector<char>* target = static_cast<std::vector<char>*>(userdata);
    LUTE_ASSERT(target);

    size_t fullsize = size * nmemb;
    target->insert(target->end(), ptr, ptr + fullsize);
    return fullsize;
}

static CurlResponse requestData(
    const std::string& url,
    const std::string& method,
    const std::string& body,
    const std::vector<std::pair<std::string, std::string>>& headers
)
{
    CURL* curl = curl_easy_init();
    CurlResponse resp;
    if (!curl)
    {
        resp.error = "failed to initialize";
        return resp;
    }

    std::vector<char> data;
    curl_slist* headerList = nullptr;

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writeFunction);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &data);
    curl_easy_setopt(curl, CURLOPT_SSL_OPTIONS, CURLSSLOPT_NATIVE_CA);

    if (method != "GET")
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method.c_str());

    if (!body.empty())
    {
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body.c_str());
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, body.size());
    }

    if (!headers.empty())
    {
        for (const auto& header_pair : headers)
        {
            std::string header_str = header_pair.first + ": " + header_pair.second;
            headerList = curl_slist_append(headerList, header_str.c_str());
        }
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headerList);
    }

    CURLcode res = curl_easy_perform(curl);

    if (headerList)
        curl_slist_free_all(headerList);

    if (res != CURLE_OK)
    {
        resp.error = curl_easy_strerror(res);
        curl_easy_cleanup(curl);
        return resp;
    }

    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &resp.status);

    resp.body = std::move(data);

    curl_header* prev = nullptr;
    curl_header* h;

    while ((h = curl_easy_nextheader(curl, CURLH_HEADER, 0, prev)))
    {
        std::string name = h->name;
        std::string value = h->value;

        if (resp.headers.contains(name))
        {
            resp.headers[name] += ", " + value;
        }
        else
        {
            resp.headers[name] = value;
        }
        prev = h;
    }

    curl_easy_cleanup(curl);
    return resp;
}

struct WebSocketHandle : std::enable_shared_from_this<WebSocketHandle>
{
    Runtime* runtime = nullptr;
    CURL* curl = nullptr;
    curl_slist* headerList = nullptr;
    std::shared_ptr<Ref> onOpenRef;
    std::shared_ptr<Ref> onMessageRef;
    std::shared_ptr<Ref> onCloseRef;
    std::shared_ptr<Ref> onErrorRef;
    WebSocketPollState* pollState = nullptr;
    std::atomic<bool> isClosed{false};
    std::atomic<bool> hasScheduledClose{false};
    std::atomic<bool> hasPendingToken{false};
    std::mutex curlMutex;
    int activePollEvents = 0;
    std::vector<char> recvBuffer = std::vector<char>(16 * 1024);
    std::string currentMessage;
    bool currentBinary = false;
    bool hasCurrentMessage = false;
    std::string closePayload;
    Luau::VecDeque<PendingSend> pendingSends;

    void scheduleCallback(const std::shared_ptr<Ref>& callback, std::function<int(lua_State*)> argPusher)
    {
        if (!callback || !runtime)
            return;

        runtime->scheduleLuauCallback(callback, std::move(argPusher));
    }

    void scheduleCloseCallback(int closeCode = 1000, std::string closeReason = "")
    {
        bool expected = false;
        if (!hasScheduledClose.compare_exchange_strong(expected, true))
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

    void stopPolling()
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

    void failPendingSends(const std::string& error)
    {
        while (!pendingSends.empty())
        {
            pendingSends.front().token->fail(error);
            pendingSends.pop_front();
        }
    }

    void finishClose(bool sendCloseFrame)
    {
        stopPolling();
        failPendingSends("websocket is closed");

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

        if (runtime && hasPendingToken.exchange(false))
            runtime->releasePendingToken();
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
                if (!state)
                    return;

                if (status < 0)
                {
                    state->owner->closeWithError(uv_strerror(status));
                    return;
                }

                if (events & UV_READABLE)
                    state->owner->processIncoming();

                if (!state->owner->isClosed.load() && (events & UV_WRITABLE))
                    state->owner->flushOutgoing();
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

    void closeWithCode(int closeCode = 1000, std::string closeReason = "", bool sendCloseFrame = true)
    {
        bool expected = false;
        if (!isClosed.compare_exchange_strong(expected, true))
            return;

        scheduleCloseCallback(closeCode, std::move(closeReason));
        finishClose(sendCloseFrame);
    }

    void closeWithError(std::string error)
    {
        bool expected = false;
        if (!isClosed.compare_exchange_strong(expected, true))
            return;

        scheduleCallback(
            onErrorRef,
            [error = std::move(error)](lua_State* L)
            {
                lua_pushlstring(L, error.data(), error.size());
                return 1;
            }
        );

        scheduleCloseCallback(1006);
        finishClose(false);
    }

    void processIncoming()
    {
        while (!isClosed.load())
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

            if (isClosed.load())
                return;

            if (result == CURLE_AGAIN)
                return;

            if (result != CURLE_OK)
            {
                if (isClosed.load() || hasScheduledClose.load())
                    return;

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

                int closeCode = 1000;
                std::string closeReason;

                if (closePayload.size() >= 2)
                {
                    const unsigned char* payload = reinterpret_cast<const unsigned char*>(closePayload.data());
                    closeCode = int((payload[0] << 8) | payload[1]);
                    if (closePayload.size() > 2)
                        closeReason.assign(closePayload.data() + 2, closePayload.size() - 2);
                }

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
                    currentMessage.clear();
                    currentBinary = (meta->flags & CURLWS_BINARY) != 0;
                    hasCurrentMessage = true;
                }
                else if (!hasCurrentMessage)
                {
                    currentMessage.clear();
                    currentBinary = false;
                    hasCurrentMessage = true;
                }

                currentMessage.append(recvBuffer.data(), receivedLength);

                if (meta->bytesleft == 0)
                {
                    std::string message = std::move(currentMessage);
                    bool binary = currentBinary;
                    hasCurrentMessage = false;

                    scheduleCallback(
                        onMessageRef,
                        [message = std::move(message), binary](lua_State* L)
                        {
                            if (binary)
                            {
                                void* buf = lua_newbuffer(L, message.size());
                                if (!message.empty())
                                    memcpy(buf, message.data(), message.size());
                            }
                            else
                            {
                                lua_pushlstring(L, message.data(), message.size());
                            }
                            return 1;
                        }
                    );
                }
            }
        }
    }

    bool startPolling(curl_socket_t socket)
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
            stopPolling();
            return false;
        }

        return true;
    }

    void flushOutgoing()
    {
        while (!pendingSends.empty() && !isClosed.load())
        {
            PendingSend& pending = pendingSends.front();

            size_t sent = 0;
            CURLcode result = CURLE_OK;

            {
                std::lock_guard<std::mutex> lock(curlMutex);
                if (!curl)
                {
                    failPendingSends("websocket is closed");
                    return;
                }

                size_t remaining = pending.payload->size() - pending.offset;
                const char* data = remaining > 0 ? pending.payload->data() + pending.offset : pending.payload->data();

                result =
                    curl_ws_send(curl, data, remaining, &sent, 0, pending.binary ? CURLWS_BINARY : CURLWS_TEXT);
            }

            if (result == CURLE_AGAIN)
                break;

            if (result != CURLE_OK)
            {
                pending.token->fail("websocket send failed: " + std::string(curl_easy_strerror(result)));
                pendingSends.pop_front();
                continue;
            }

            pending.offset += sent;

            if (pending.payload->empty() || pending.offset >= pending.payload->size())
            {
                pending.token->complete(
                    [](lua_State*)
                    {
                        return 0;
                    }
                );
                pendingSends.pop_front();
                continue;
            }

            if (sent == 0)
                break;
        }

        if (!isClosed.load() && !updatePollingInterest())
            closeWithError("failed to update websocket polling");
    }

    void close()
    {
        closeWithCode();
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

static std::shared_ptr<WebSocketHandle>* getWebSocketHandle(lua_State* L, int index)
{
    return static_cast<std::shared_ptr<WebSocketHandle>*>(lua_touserdatatagged(L, index, kWebSocketHandleTag));
}

int request(lua_State* L)
{
    std::string url = luaL_checkstring(L, 1);
    std::string method = "GET";
    std::string body = "";
    std::vector<std::pair<std::string, std::string>> headers;

    if (lua_istable(L, 2))
    {
        lua_getfield(L, 2, "method");
        if (lua_isstring(L, -1))
            method = lua_tostring(L, -1);
        lua_pop(L, 1);

        lua_getfield(L, 2, "body");
        if (lua_isstring(L, -1))
        {
            size_t len;
            const char* data = lua_tolstring(L, -1, &len);
            body.assign(data, data + len);
        }
        lua_pop(L, 1);

        lua_getfield(L, 2, "headers");
        if (lua_istable(L, -1))
        {
            lua_pushnil(L);
            while (lua_next(L, -2))
            {
                if (lua_isstring(L, -2) && lua_isstring(L, -1))
                {
                    std::string key = lua_tostring(L, -2);
                    std::string value = lua_tostring(L, -1);
                    headers.emplace_back(key, value);
                }
                lua_pop(L, 1);
            }
        }
        lua_pop(L, 1);
    }

    auto token = getResumeToken(L);

    token->runtime->runInWorkQueue(
        [url = std::move(url), method = std::move(method), body = std::move(body), headers = std::move(headers), token]
        {
            CurlResponse resp = requestData(url, method, body, headers);
            if (!resp.error.empty())
            {
                token->fail("network request failed: " + resp.error);
                return;
            }

            token->complete(
                [resp = std::move(resp)](lua_State* L)
                {
                    lua_createtable(L, 0, 4);

                    lua_pushstring(L, "body");
                    lua_pushlstring(L, resp.body.data(), resp.body.size());
                    lua_settable(L, -3);

                    lua_pushstring(L, "headers");
                    lua_createtable(L, 0, resp.headers.size());
                    for (const auto& header : resp.headers)
                    {
                        lua_pushlstring(L, header.first.data(), header.first.size());
                        lua_pushlstring(L, header.second.data(), header.second.size());
                        lua_settable(L, -3);
                    }
                    lua_settable(L, -3);

                    lua_pushstring(L, "status");
                    lua_pushinteger(L, resp.status);
                    lua_settable(L, -3);

                    lua_pushstring(L, "ok");
                    lua_pushboolean(L, (resp.status >= 200 && resp.status < 300));
                    lua_settable(L, -3);

                    return 1;
                }
            );
        }
    );

    return lua_yield(L, 0);
}

int ws_send(lua_State* L)
{
    if (lua_gettop(L) != 2)
        luaL_errorL(L, "websocket send expects exactly 1 payload argument");

    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handleStorage = getWebSocketHandle(L, 1);
    if (!handleStorage || !(*handleStorage) || (*handleStorage)->isClosed.load())
        luaL_errorL(L, "Invalid or closed websocket");

    std::shared_ptr<WebSocketHandle> handle = *handleStorage;

    WebSocketPayload payloadData = extractWebSocketPayload(L, 2);

    auto payload = std::make_shared<std::string>(payloadData.data, payloadData.length);
    auto token = getResumeToken(L);

    handle->pendingSends.push_back({std::move(payload), payloadData.binary, 0, token});
    token->runtime->schedule(
        [handle = std::move(handle)]
        {
            if (handle->isClosed.load())
            {
                handle->failPendingSends("websocket is closed");
                return;
            }

            handle->flushOutgoing();
        }
    );

    return lua_yield(L, 0);
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
                {
                    std::string key = lua_tostring(L, -2);
                    std::string value = lua_tostring(L, -1);
                    headers.emplace_back(key, value);
                }
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

    token->runtime->runInWorkQueue(
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
            curl_easy_setopt(curl, CURLOPT_SSL_OPTIONS, CURLSSLOPT_NATIVE_CA);
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
                    auto handle = std::make_shared<WebSocketHandle>();
                    handle->runtime = runtime;
                    handle->curl = curl;
                    handle->headerList = headerList;
                    handle->onOpenRef = std::move(onOpenRef);
                    handle->onMessageRef = std::move(onMessageRef);
                    handle->onCloseRef = std::move(onCloseRef);
                    handle->onErrorRef = std::move(onErrorRef);

                    if (!handle->startPolling(socket))
                    {
                        handle->finishClose(false);
                        luaL_errorL(L, "failed to initialize websocket polling");
                    }

                    auto* storage =
                        new (static_cast<std::shared_ptr<WebSocketHandle>*>(lua_newuserdatataggedwithmetatable(
                            L,
                            sizeof(std::shared_ptr<WebSocketHandle>),
                            kWebSocketHandleTag
                        ))) std::shared_ptr<WebSocketHandle>(handle);
                    (void)storage;

                    runtime->addPendingToken();
                    handle->hasPendingToken.store(true);
                    handle->scheduleCallback(
                        handle->onOpenRef,
                        [](lua_State*)
                        {
                            return 0;
                        }
                    );
                    return 1;
                }
            );
        }
    );

    return lua_yield(L, 0);
}

} // namespace net::client

const char* const NetClient::properties[] = {nullptr};

const luaL_Reg NetClient::lib[] = {
    {"request", net::client::request},
    {"websocket", net::client::websocket},
    {nullptr, nullptr},
};

int NetClient::pushLibrary(lua_State* L)
{
    globalCurlInit();
    initializeNetClient(L);

    lua_createtable(L, 0, std::size(NetClient::lib));

    for (auto& [name, func] : NetClient::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    return 1;
}

int luteopen_net_client(lua_State* L)
{
    return NetClient::pushLibrary(L);
}
