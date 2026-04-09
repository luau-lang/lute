#include "lute/net.h"

#include "lute/common.h"
#include "lute/runtime.h"
#include "lute/userdatas.h"

#include "Luau/DenseHash.h"

#include "lua.h"
#include "lualib.h"

#include "curl/curl.h"
#include "curl/websockets.h"

#include <atomic>
#include <cstring>
#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
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
    std::thread recvThread;
    std::atomic<bool> isClosed{false};
    std::atomic<bool> hasScheduledClose{false};
    std::mutex curlMutex;

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

    void startRecvLoop()
    {
        {
            std::lock_guard<std::mutex> lock(curlMutex);
            curl_easy_setopt(curl, CURLOPT_TIMEOUT_MS, 1000L);
        }

        std::shared_ptr<WebSocketHandle> self = shared_from_this();
        recvThread = std::thread(
            [self]
            {
                self->scheduleCallback(
                    self->onOpenRef,
                    [](lua_State*)
                    {
                        return 0;
                    }
                );

                std::vector<char> buffer(16 * 1024);
                std::string currentMessage;
                bool currentBinary = false;
                bool hasCurrentMessage = false;
                std::string closePayload;

                while (!self->isClosed.load())
                {
                    size_t receivedLength = 0;
                    const curl_ws_frame* meta = nullptr;
                    CURLcode result = CURLE_OK;

                    {
                        std::lock_guard<std::mutex> lock(self->curlMutex);
                        if (!self->curl)
                            break;

                        result = curl_ws_recv(self->curl, buffer.data(), buffer.size(), &receivedLength, &meta);
                    }

                    if (self->isClosed.load())
                        break;

                    if (result == CURLE_AGAIN || result == CURLE_OPERATION_TIMEDOUT)
                        continue;

                    if (result != CURLE_OK)
                    {
                        if (self->isClosed.load() || self->hasScheduledClose.load())
                            break;

                        std::string error = curl_easy_strerror(result);
                        self->scheduleCallback(
                            self->onErrorRef,
                            [error = std::move(error)](lua_State* L)
                            {
                                lua_pushlstring(L, error.data(), error.size());
                                return 1;
                            }
                        );
                        break;
                    }

                    if (!meta)
                        continue;

                    if (meta->flags & CURLWS_CLOSE)
                    {
                        closePayload.append(buffer.data(), receivedLength);

                        if (meta->bytesleft != 0)
                            continue;

                        int closeCode = 1000;
                        std::string closeReason;

                        if (closePayload.size() >= 2)
                        {
                            const unsigned char* payload =
                                reinterpret_cast<const unsigned char*>(closePayload.data());
                            closeCode = int((payload[0] << 8) | payload[1]);
                            if (closePayload.size() > 2)
                                closeReason.assign(closePayload.data() + 2, closePayload.size() - 2);
                        }

                        self->scheduleCloseCallback(closeCode, std::move(closeReason));
                        break;
                    }

                    if (meta->flags & CURLWS_PING)
                    {
                        size_t sent = 0;
                        std::lock_guard<std::mutex> lock(self->curlMutex);
                        if (self->curl)
                            (void)curl_ws_send(self->curl, buffer.data(), receivedLength, &sent, 0, CURLWS_PONG);
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

                        currentMessage.append(buffer.data(), receivedLength);

                        if (meta->bytesleft == 0)
                        {
                            std::string message = std::move(currentMessage);
                            bool binary = currentBinary;
                            hasCurrentMessage = false;

                            self->scheduleCallback(
                                self->onMessageRef,
                                [message = std::move(message), binary](lua_State* L)
                                {
                                    lua_pushlstring(L, message.data(), message.size());
                                    lua_pushboolean(L, binary);
                                    return 2;
                                }
                            );
                        }
                    }
                }

                self->close();
            }
        );
    }

    void close()
    {
        bool expected = false;
        if (!isClosed.compare_exchange_strong(expected, true))
            return;

        scheduleCloseCallback();

        {
            std::lock_guard<std::mutex> lock(curlMutex);
            if (curl)
            {
                size_t sent = 0;
                (void)curl_ws_send(curl, "", 0, &sent, 0, CURLWS_CLOSE);
                curl_easy_cleanup(curl);
                curl = nullptr;
            }

            if (headerList)
            {
                curl_slist_free_all(headerList);
                headerList = nullptr;
            }
        }

        if (runtime)
            runtime->releasePendingToken();
    }

    ~WebSocketHandle()
    {
        close();
        if (recvThread.joinable())
        {
            if (std::this_thread::get_id() == recvThread.get_id())
                recvThread.detach();
            else
                recvThread.join();
        }

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
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handleStorage = getWebSocketHandle(L, 1);
    if (!handleStorage || !(*handleStorage) || (*handleStorage)->isClosed.load())
        luaL_errorL(L, "Invalid or closed websocket");

    std::shared_ptr<WebSocketHandle> handle = *handleStorage;

    size_t len = 0;
    const char* data = luaL_checklstring(L, 2, &len);
    bool binary = lua_isboolean(L, 3) && lua_toboolean(L, 3);

    auto payload = std::make_shared<std::string>(data, len);
    auto token = getResumeToken(L);

    token->runtime->runInWorkQueue(
        [handle = std::move(handle), payload = std::move(payload), binary, token]
        {
            if (handle->isClosed.load())
            {
                token->fail("websocket is closed");
                return;
            }

            size_t sent = 0;
            CURLcode result = CURLE_OK;

            {
                std::lock_guard<std::mutex> lock(handle->curlMutex);
                if (!handle->curl)
                {
                    token->fail("websocket is closed");
                    return;
                }

                result = curl_ws_send(
                    handle->curl,
                    payload->data(),
                    payload->size(),
                    &sent,
                    0,
                    binary ? CURLWS_BINARY : CURLWS_TEXT
                );
            }

            if (result != CURLE_OK)
            {
                token->fail("websocket send failed: " + std::string(curl_easy_strerror(result)));
                return;
            }

            token->complete(
                [](lua_State*)
                {
                    return 0;
                }
            );
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
    std::optional<std::string> protocol;
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

        lua_getfield(L, 2, "protocol");
        if (lua_isstring(L, -1))
            protocol = lua_tostring(L, -1);
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
         protocol = std::move(protocol),
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

            if (protocol)
            {
                std::string protocolHeader = "Sec-WebSocket-Protocol: " + *protocol;
                headerList = curl_slist_append(headerList, protocolHeader.c_str());
            }

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

            token->complete(
                [runtime,
                 curl,
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

                    auto* storage =
                        new (static_cast<std::shared_ptr<WebSocketHandle>*>(lua_newuserdatataggedwithmetatable(
                            L,
                            sizeof(std::shared_ptr<WebSocketHandle>),
                            kWebSocketHandleTag
                        ))) std::shared_ptr<WebSocketHandle>(handle);
                    (void)storage;

                    runtime->addPendingToken();
                    handle->startRecvLoop();
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
