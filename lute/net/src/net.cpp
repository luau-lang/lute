#include "lute/net.h"

#include "lute/runtime.h"
#include "lute/userdatas.h"

#include "Luau/DenseHash.h"
#include "Luau/Variant.h"

#include "lua.h"
#include "lualib.h"

#include "curl/curl.h"
#include "curl/websockets.h"
#include "uv.h"

#include <memory>
#include <optional>
#include <thread>
#include <atomic>
#include <mutex>
#include <string>
#include <utility>
#include <vector>

#include "App.h"
#include "Loop.h"

namespace net
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

static size_t writeFunction(void* contents, size_t size, size_t nmemb, void* context)
{
    std::vector<char>& target = *(std::vector<char>*)context;
    size_t fullsize = size * nmemb;

    target.insert(target.end(), (char*)contents, (char*)contents + fullsize);

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
    std::vector<char> headerData;
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

    // TODO: add cancellations
    token->runtime->runInWorkQueue(
        [=]
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

struct WebSocketHandle
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
    std::mutex curlMutex;

    void scheduleCallback(const std::shared_ptr<Ref>& callback, std::function<int(lua_State*)> cont)
    {
        if (!callback || !runtime)
            return;

        lua_State* newThread = lua_newthread(runtime->GL);
        luaL_sandboxthread(newThread);
        std::shared_ptr<Ref> ref = getRefForThread(newThread);
        lua_pop(runtime->GL, 1);

        runtime->scheduleLuauResume(ref, std::move(cont));
    }

    void startRecvLoop()
    {
        // Avoid busy waiting on no data
        {
            std::lock_guard<std::mutex> lock(curlMutex);
            curl_easy_setopt(curl, CURLOPT_TIMEOUT_MS, 1000L);
        }

        recvThread = std::thread(
            [this]
            {
                scheduleCallback(
                    onOpenRef,
                    [this](lua_State* L)
                    {
                        onOpenRef->push(L);
                        return 0;
                    }
                );

                std::vector<char> buffer(16 * 1024);
                std::string currentMsg;
                bool currentBinary = false;
                bool hasCurrent = false;
                std::string closePayload;

                while (!isClosed.load())
                {
                    size_t rlen = 0;
                    const curl_ws_frame* meta = nullptr;
                    CURLcode r;

                    {
                        std::lock_guard<std::mutex> lock(curlMutex);
                        r = curl_ws_recv(curl, buffer.data(), buffer.size(), &rlen, &meta);
                    }

                    if (isClosed.load())
                        break;

                    if (r == CURLE_AGAIN || r == CURLE_OPERATION_TIMEDOUT)
                        continue;

                    if (r != CURLE_OK)
                    {
                        std::string err = curl_easy_strerror(r);
                        scheduleCallback(
                            onErrorRef,
                            [this, err](lua_State* L)
                            {
                                onErrorRef->push(L);
                                lua_pushlstring(L, err.c_str(), err.size());
                                return 1;
                            }
                        );
                        break;
                    }

                    if (!meta)
                        continue;

                    if (meta->flags & CURLWS_CLOSE)
                    {
                        closePayload.append(buffer.data(), rlen);

                        if (meta->bytesleft == 0)
                        {
                            int closeCode = 1000;
                            std::string closeReason;

                            if (closePayload.size() >= 2)
                            {
                                const unsigned char* p = reinterpret_cast<const unsigned char*>(closePayload.data());
                                closeCode = (int)((p[0] << 8) | p[1]);
                                if (closePayload.size() > 2)
                                    closeReason.assign(closePayload.data() + 2, closePayload.size() - 2);
                            }

                            scheduleCallback(
                                onCloseRef,
                                [this, closeCode, closeReason = std::move(closeReason)](lua_State* L)
                                {
                                    onCloseRef->push(L);
                                    lua_pushinteger(L, closeCode);
                                    lua_pushlstring(L, closeReason.data(), closeReason.size());
                                    return 2;
                                }
                            );
                        }
                        break;
                    }

                    if (meta->flags & CURLWS_PING)
                    {
                        size_t sent = 0;
                        std::lock_guard<std::mutex> lock(curlMutex);
                        (void)curl_ws_send(curl, buffer.data(), rlen, &sent, 0, CURLWS_PONG);
                        continue;
                    }

                    if (meta->flags & (CURLWS_TEXT | CURLWS_BINARY | CURLWS_CONT))
                    {
                        // Start of a new message
                        if (meta->flags & (CURLWS_TEXT | CURLWS_BINARY))
                        {
                            currentMsg.clear();
                            currentBinary = (meta->flags & CURLWS_BINARY) != 0;
                            hasCurrent = true;
                        }
                        else if (!hasCurrent)
                        {
                            // Continuation without a start frame; treat as text.
                            currentMsg.clear();
                            currentBinary = false;
                            hasCurrent = true;
                        }

                        currentMsg.append(buffer.data(), rlen);

                        // bytesleft indicates remaining bytes in this frame.
                        if (meta->bytesleft == 0)
                        {
                            std::string msg = std::move(currentMsg);
                            bool binary = currentBinary;
                            hasCurrent = false;

                            scheduleCallback(
                                onMessageRef,
                                [this, msg = std::move(msg), binary](lua_State* L)
                                {
                                    onMessageRef->push(L);
                                    lua_pushlstring(L, msg.data(), msg.size());
                                    lua_pushboolean(L, binary);
                                    return 2;
                                }
                            );
                        }
                    }
                }

                close();
            }
        );
    }

    void close()
    {
        bool expected = false;
        if (!isClosed.compare_exchange_strong(expected, true))
            return;

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
        if (recvThread.joinable() && std::this_thread::get_id() != recvThread.get_id())
            recvThread.join();

        onOpenRef.reset();
        onMessageRef.reset();
        onCloseRef.reset();
        onErrorRef.reset();
    }
};

static int ws_send(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handle = static_cast<WebSocketHandle*>(lua_touserdatatagged(L, 1, kWebSocketHandleTag));
    if (!handle || handle->isClosed.load())
        luaL_errorL(L, "Invalid or closed websocket");

    size_t len;
    const char* data = luaL_checklstring(L, 2, &len);
    bool binary = false;
    if (lua_isboolean(L, 3))
        binary = lua_toboolean(L, 3);

    auto payload = std::make_shared<std::string>(data, len);
    auto token = getResumeToken(L);

    token->runtime->runInWorkQueue(
        [handle, payload = std::move(payload), binary, token]
        {
            if (handle->isClosed.load())
            {
                token->fail("websocket is closed");
                return;
            }

            size_t sent = 0;
            CURLcode r;
            {
                std::lock_guard<std::mutex> lock(handle->curlMutex);
                r = curl_ws_send(
                    handle->curl,
                    payload->data(),
                    payload->size(),
                    &sent,
                    0,
                    binary ? CURLWS_BINARY : CURLWS_TEXT
                );
            }

            if (r != CURLE_OK)
            {
                token->fail("websocket send failed: " + std::string(curl_easy_strerror(r)));
                return;
            }

            token->complete(
                [](lua_State* L)
                {
                    lua_pushboolean(L, 1);
                    return 1;
                }
            );
        }
    );

    return lua_yield(L, 0);
}

static int ws_close(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handle = static_cast<WebSocketHandle*>(lua_touserdatatagged(L, 1, kWebSocketHandleTag));
    if (!handle)
        luaL_errorL(L, "Invalid websocket");

    handle->close();
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
        [=, url = std::move(url), headers = std::move(headers), protocol = std::move(protocol)]() mutable
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
                std::string protoHeader = "Sec-WebSocket-Protocol: " + *protocol;
                headerList = curl_slist_append(headerList, protoHeader.c_str());
            }

            for (const auto& header_pair : headers)
            {
                std::string header_str = header_pair.first + ": " + header_pair.second;
                headerList = curl_slist_append(headerList, header_str.c_str());
            }
            if (headerList)
                curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headerList);

            CURLcode res = curl_easy_perform(curl);
            if (res != CURLE_OK)
            {
                std::string err = curl_easy_strerror(res);
                if (headerList)
                    curl_slist_free_all(headerList);
                curl_easy_cleanup(curl);
                token->fail("websocket connect failed: " + err);
                return;
            }

            token->complete(
                [=](lua_State* L) mutable
                {
                    auto* ws =
                        new (static_cast<WebSocketHandle*>(lua_newuserdatataggedwithmetatable(
                            L,
                            sizeof(WebSocketHandle),
                            kWebSocketHandleTag
                        ))) WebSocketHandle{};

                    ws->runtime = runtime;
                    ws->curl = curl;
                    ws->headerList = headerList;
                    ws->onOpenRef = onOpenRef;
                    ws->onMessageRef = onMessageRef;
                    ws->onCloseRef = onCloseRef;
                    ws->onErrorRef = onErrorRef;

                    runtime->addPendingToken();
                    ws->startRecvLoop();

                    return 1;
                }
            );
        }
    );

    return lua_yield(L, 0);
}

using uWSApp = Luau::Variant<std::unique_ptr<uWS::App>, std::unique_ptr<uWS::SSLApp>>;

static const int kEmptyServerKey = 0;
static Luau::DenseHashMap<int, uWSApp> serverInstances(kEmptyServerKey);
static Luau::DenseHashMap<int, std::shared_ptr<struct ServerLoopState>> serverStates(kEmptyServerKey);
static int nextServerId = 1;

struct ServerLoopState
{
    Luau::Variant<uWS::App*, uWS::SSLApp*> app;
    Runtime* runtime;
    bool running = true;
    std::function<void()> loopFunction;
    std::shared_ptr<Ref> handlerRef;
    std::shared_ptr<Ref> serverRef;
    std::shared_ptr<Ref> wsOpenRef;
    std::shared_ptr<Ref> wsMessageRef;
    std::shared_ptr<Ref> wsCloseRef;
    std::shared_ptr<Ref> wsDrainRef;
    bool hasWebSocket = false;
    std::string hostname;
    int port;
    bool reusePort = false;
};

template <bool SSL>
struct PerSocketData;

struct ServerWebSocketHandle
{
    void* wsPtr = nullptr; // uWS::WebSocket<SSL, true, PerSocketData<SSL>>*
    std::atomic<bool> closed{false};
    std::mutex sendMutex;
    bool (*sendFn)(void* wsPtr, std::string_view data, bool binary) = nullptr;
    void (*closeFn)(void* wsPtr, uint16_t code, std::string_view message) = nullptr;
};

template <bool SSL>
struct PerSocketData
{
    std::weak_ptr<ServerLoopState> state;
    std::shared_ptr<ServerWebSocketHandle> handle;
};

// Forward declarations used by upgrade decision
static void parseQuery(const std::string_view& query, lua_State* L);
template <typename ReqT>
static void parseHeaders(ReqT* req, lua_State* L);

static void resumeWith(
    const std::shared_ptr<ServerLoopState>& state,
    const std::shared_ptr<Ref>& callback,
    std::function<int(lua_State*)> cont
)
{
    if (!callback)
        return;

    lua_State* L = lua_newthread(state->runtime->GL);
    luaL_sandboxthread(L);
    std::shared_ptr<Ref> ref = getRefForThread(L);
    lua_pop(state->runtime->GL, 1);

    state->runtime->scheduleLuauResume(
        ref,
        [callback, cont = std::move(cont)](lua_State* L) mutable
        {
            callback->push(L);
            return cont(L);
        }
    );
}

static int server_upgrade_noop(lua_State* L)
{
    // upvalues: res, req, upgradedPtr (unused here)
    lua_pushboolean(L, 0);
    return 1;
}

template <bool SSL>
static int server_upgrade_do(lua_State* L)
{
    auto* res = (uWS::HttpResponse<SSL>*)lua_touserdata(L, lua_upvalueindex(1));
    auto* req = (uWS::HttpRequest*)lua_touserdata(L, lua_upvalueindex(2));
    auto* context = (us_socket_context_t*)lua_touserdata(L, lua_upvalueindex(3));
    auto* upgradedPtr = (bool*)lua_touserdata(L, lua_upvalueindex(4));

    if (!res || !req || !context || !upgradedPtr)
    {
        lua_pushboolean(L, 0);
        return 1;
    }

    std::string_view key = req->getHeader("sec-websocket-key");
    std::string_view protocol = req->getHeader("sec-websocket-protocol");
    std::string_view extensions = req->getHeader("sec-websocket-extensions");

    if (key.empty())
    {
        lua_pushboolean(L, 0);
        return 1;
    }

    PerSocketData<SSL> userData;
    res->template upgrade<PerSocketData<SSL>>(std::move(userData), key, protocol, extensions, context);
    *upgradedPtr = true;
    lua_pushboolean(L, 1);
    return 1;
}

template <bool SSL>
static bool wsSendImpl(void* wsPtr, std::string_view data, bool binary)
{
    auto* ws = static_cast<uWS::WebSocket<SSL, true, PerSocketData<SSL>>*>(wsPtr);
    auto status = ws->send(data, binary ? uWS::OpCode::BINARY : uWS::OpCode::TEXT);
    return status != decltype(status)::DROPPED;
}

template <bool SSL>
static void wsCloseImpl(void* wsPtr, uint16_t code, std::string_view message)
{
    auto* ws = static_cast<uWS::WebSocket<SSL, true, PerSocketData<SSL>>*>(wsPtr);
    ws->end((int)code, message);
}

static int server_ws_send(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handlePtr =
        static_cast<std::shared_ptr<ServerWebSocketHandle>*>(lua_touserdatatagged(L, 1, kServerWebSocketHandleTag));
    if (!handlePtr || !(*handlePtr) || (*handlePtr)->closed.load())
    {
        lua_pushboolean(L, 0);
        return 1;
    }

    size_t len;
    const char* data = luaL_checklstring(L, 2, &len);
    bool binary = false;
    if (lua_isboolean(L, 3))
        binary = lua_toboolean(L, 3);

    std::lock_guard<std::mutex> lock((*handlePtr)->sendMutex);
    bool ok = false;
    if (!(*handlePtr)->closed.load() && (*handlePtr)->wsPtr && (*handlePtr)->sendFn)
    {
        ok = (*handlePtr)->sendFn((*handlePtr)->wsPtr, std::string_view(data, len), binary);
    }

    lua_pushboolean(L, ok);
    return 1;
}

static int server_ws_close(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handlePtr =
        static_cast<std::shared_ptr<ServerWebSocketHandle>*>(lua_touserdatatagged(L, 1, kServerWebSocketHandleTag));
    if (!handlePtr || !(*handlePtr) || (*handlePtr)->closed.load() || !(*handlePtr)->wsPtr)
        return 0;

    int code = 1000;
    if (lua_isnumber(L, 2))
        code = lua_tointeger(L, 2);

    std::string message;
    if (lua_isstring(L, 3))
        message = lua_tostring(L, 3);

    std::lock_guard<std::mutex> lock((*handlePtr)->sendMutex);
    if (!(*handlePtr)->closed.load() && (*handlePtr)->wsPtr && (*handlePtr)->closeFn)
    {
        (*handlePtr)->closeFn((*handlePtr)->wsPtr, (uint16_t)code, message);
    }

    return 0;
}

template <bool SSL>
static void pushServerWebSocket(lua_State* L, const std::shared_ptr<ServerWebSocketHandle>& handle)
{
    auto* ud = new (static_cast<std::shared_ptr<ServerWebSocketHandle>*>(lua_newuserdatataggedwithmetatable(
        L,
        sizeof(std::shared_ptr<ServerWebSocketHandle>),
        kServerWebSocketHandleTag
    ))) std::shared_ptr<ServerWebSocketHandle>(handle);
    (void)ud;
}

static void parseQuery(const std::string_view& query, lua_State* L)
{
    lua_createtable(L, 0, 0);
    size_t start = 1; // Skip the '?'
    size_t end = query.find('&');
    while (end != std::string::npos)
    {
        std::string_view pair = std::string_view(query.data() + start, end - start);
        size_t eq = pair.find('=');
        if (eq != std::string::npos)
        {
            std::string_view key = std::string_view(pair.data(), eq);
            std::string_view value = uWS::getDecodedQueryValue(key, query);
            lua_pushlstring(L, key.data(), key.size());
            lua_pushlstring(L, value.data(), value.size());
            lua_settable(L, -3);
        }
        start = end + 1;
        end = query.find('&', start);
    }
    std::string_view pair = std::string_view(query.data() + start, query.size());
    size_t eq = pair.find('=');
    if (eq != std::string::npos)
    {
        std::string_view key = std::string_view(pair.data(), eq);
        std::string_view value = uWS::getDecodedQueryValue(key, query);
        lua_pushlstring(L, key.data(), key.size());
        lua_pushlstring(L, value.data(), value.size());
        lua_settable(L, -3);
    }
}

template <typename ReqT>
static void parseHeaders(ReqT* req, lua_State* L)
{
    lua_createtable(L, 0, 0);
    for (const auto& header : *req)
    {
        lua_pushlstring(L, header.first.data(), header.first.size());
        lua_pushlstring(L, header.second.data(), header.second.size());
        lua_settable(L, -3);
    }
}

static void handleResponse(auto* res, lua_State* L, int responseIndex)
{
    // Check if the response is a string or a table
    if (lua_isstring(L, responseIndex))
    {
        std::string body = lua_tostring(L, responseIndex);
        res->writeStatus("200 OK");
        res->writeHeader("Content-Type", "text/html");
        res->end(body);
        return;
    }

    if (!lua_istable(L, responseIndex))
    {
        res->writeStatus("500 Internal Server Error");
        res->end("Handler must return a string or a response table");
        return;
    }


    lua_getfield(L, responseIndex, "status");
    int status = lua_isnumber(L, -1) ? lua_tointeger(L, -1) : 200;
    lua_pop(L, 1);

    std::string statusText;
    switch (status)
    {
    case 200:
        statusText = "200 OK";
        break;
    case 201:
        statusText = "201 Created";
        break;
    case 204:
        statusText = "204 No Content";
        break;
    case 400:
        statusText = "400 Bad Request";
        break;
    case 401:
        statusText = "401 Unauthorized";
        break;
    case 403:
        statusText = "403 Forbidden";
        break;
    case 404:
        statusText = "404 Not Found";
        break;
    case 500:
        statusText = "500 Internal Server Error";
        break;
    default:
        statusText = std::to_string(status) + " Status";
        break;
    }
    res->writeStatus(statusText);

    lua_getfield(L, responseIndex, "headers");
    if (lua_istable(L, -1))
    {
        lua_pushnil(L);
        while (lua_next(L, -2))
        {
            if (lua_isstring(L, -2) && lua_isstring(L, -1))
            {
                std::string headerName = lua_tostring(L, -2);
                std::string headerValue = lua_tostring(L, -1);
                res->writeHeader(headerName, headerValue);
            }
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);

    lua_getfield(L, responseIndex, "body");

    std::string body = "";
    size_t bodyLength;
    const char* bodyData = lua_tolstring(L, -1, &bodyLength);
    body.assign(bodyData, bodyData + bodyLength);
    lua_pop(L, 1);

    res->end(body);
}

struct PreparedHandler
{
    lua_State* L;
    std::shared_ptr<Ref> threadRef;
};

template <typename ReqT, typename PushUpvalues>
static PreparedHandler prepareServerHandlerThread(
    std::shared_ptr<ServerLoopState> state,
    auto* res,
    ReqT* req,
    const std::string& method,
    const std::string_view& path,
    const std::string_view& query,
    const std::string_view& body,
    lua_CFunction upgradeFn,
    int nUpvalues,
    PushUpvalues pushUpvalues,
    bool checkStack
)
{
    lua_State* L = lua_newthread(state->runtime->GL);
    luaL_sandboxthread(L);
    if (checkStack)
        lua_checkstack(L, 64);
    std::shared_ptr<Ref> threadRef = getRefForThread(L);
    lua_pop(state->runtime->GL, 1);

    lua_createtable(L, 0, 5);

    lua_pushstring(L, "method");
    lua_pushstring(L, method.c_str());
    lua_settable(L, -3);

    lua_pushstring(L, "path");
    lua_pushlstring(L, path.data(), path.size());
    lua_settable(L, -3);

    lua_pushstring(L, "query");
    parseQuery(query, L);
    lua_settable(L, -3);

    lua_pushstring(L, "headers");
    parseHeaders(req, L);
    lua_settable(L, -3);

    lua_pushstring(L, "body");
    lua_pushlstring(L, body.data(), body.size());
    lua_settable(L, -3);

    state->handlerRef->push(L);

    // second argument: existing server table (plus per-request upgrade method)
    if (state->serverRef)
        state->serverRef->push(L);
    else
        lua_newtable(L);

    // create per-request server view to avoid mutating shared server table
    // stack: req, func, serverTable
    lua_createtable(L, 0, 1); // view
    lua_createtable(L, 0, 1); // metatable
    lua_pushvalue(L, -3);     // original server table
    lua_setfield(L, -2, "__index");
    lua_setmetatable(L, -2); // set metatable on view

    pushUpvalues(L);
    lua_pushcclosure(L, upgradeFn, "server.upgrade", nUpvalues);
    lua_setfield(L, -2, "upgrade"); // set on view

    // stack: req, func, serverTable, serverView
    lua_remove(L, -2); // drop original server table, keep view
    // reorder to func, req, serverView
    lua_insert(L, -2); // req, serverView, func
    lua_insert(L, -3); // func, req, serverView

    return {L, std::move(threadRef)};
}

static void processRequest(
    std::shared_ptr<ServerLoopState> state,
    auto* res,
    auto* req,
    const std::string& method,
    const std::string_view& path,
    const std::string_view& query,
    const std::string_view& body
)
{
    bool upgraded = false;

    PreparedHandler prepared = prepareServerHandlerThread(
        state,
        res,
        req,
        method,
        path,
        query,
        body,
        server_upgrade_noop,
        3,
        [res, req, &upgraded](lua_State* L)
        {
            lua_pushlightuserdata(L, res);
            lua_pushlightuserdata(L, req);
            lua_pushlightuserdata(L, &upgraded);
        },
        false
    );

    lua_State* L = prepared.L;
    int status = lua_resume(L, nullptr, 2);
    if (status != LUA_OK && status != LUA_YIELD)
    {
        std::string error = lua_tostring(L, -1);
        lua_pop(L, 1);

        res->writeStatus("500 Internal Server Error");
        res->end("Server error: " + error);
        return;
    }

    if (upgraded)
    {
        lua_pop(L, 1);
        return;
    }

    handleResponse(res, L, -1);

    lua_pop(L, 1);
}

template <bool SSL, typename AppT>
void setupAppAndListen(AppT* app, std::shared_ptr<ServerLoopState> state, bool& success)
{
    if (state->hasWebSocket)
    {
        app->template ws<PerSocketData<SSL>>(
            "/*",
            {
                .upgrade =
                    [state](auto* res, auto* req, auto* context)
                    {
                        std::string method = std::string(req->getMethod());
                        std::transform(method.begin(), method.end(), method.begin(), ::toupper);
                        std::string_view url = req->getFullUrl();
                        std::string_view path = url;

                        size_t queryPos = url.find('?');
                        std::string query;
                        if (queryPos != std::string::npos)
                        {
                            path = std::string_view(url.data(), queryPos);
                            query = std::string_view(url.data() + queryPos, url.size() - queryPos);
                        }

                        bool upgraded = false;

                        PreparedHandler prepared = prepareServerHandlerThread(
                            state,
                            res,
                            req,
                            method,
                            path,
                            query,
                            std::string_view(""),
                            server_upgrade_do<SSL>,
                            4,
                            [res, req, context, &upgraded](lua_State* L)
                            {
                                lua_pushlightuserdata(L, res);
                                lua_pushlightuserdata(L, req);
                                lua_pushlightuserdata(L, context);
                                lua_pushlightuserdata(L, &upgraded);
                            },
                            true
                        );

                        lua_State* L = prepared.L;
                        int status = lua_resume(L, nullptr, 2);

                        if (status == LUA_YIELD)
                        {
                            res->writeStatus("500 Internal Server Error");
                            res->end("upgrade handler cannot yield");
                            lua_pop(L, 1);
                            return;
                        }

                        if (status != LUA_OK)
                        {
                            std::string error = lua_isstring(L, -1) ? lua_tostring(L, -1) : "Server error";
                            res->writeStatus("500 Internal Server Error");
                            res->end("Server error: " + error);
                            lua_pop(L, 1);
                            return;
                        }

                        if (!upgraded)
                        {
                            handleResponse(res, L, -1);
                        }

                        lua_pop(L, 1);
                    },
                .open =
                    [state](auto* ws)
                    {
                        auto* data = ws->getUserData();
                        data->state = state;
                        data->handle = std::make_shared<ServerWebSocketHandle>();
                        data->handle->wsPtr = ws;
                        data->handle->sendFn = &wsSendImpl<SSL>;
                        data->handle->closeFn = &wsCloseImpl<SSL>;

                        resumeWith(
                            state,
                            state->wsOpenRef,
                            [handle = data->handle](lua_State* L)
                            {
                                pushServerWebSocket<SSL>(L, handle);
                                return 1;
                            }
                        );
                    },
                .message =
                    [state](auto* ws, std::string_view message, uWS::OpCode opCode)
                    {
                        auto handle = ws->getUserData()->handle;

                        std::string msg(message.data(), message.size());
                        bool binary = (opCode == uWS::OpCode::BINARY);

                        resumeWith(
                            state,
                            state->wsMessageRef,
                            [handle, msg = std::move(msg), binary](lua_State* L)
                            {
                                pushServerWebSocket<SSL>(L, handle);
                                lua_pushlstring(L, msg.data(), msg.size());
                                lua_pushboolean(L, binary);
                                return 3;
                            }
                        );
                    },
                .drain =
                    [state](auto* ws)
                    {
                        auto handle = ws->getUserData()->handle;

                        resumeWith(
                            state,
                            state->wsDrainRef,
                            [handle](lua_State* L)
                            {
                                pushServerWebSocket<SSL>(L, handle);
                                return 1;
                            }
                        );
                    },
                .close =
                    [state](auto* ws, int code, std::string_view message)
                    {
                        auto handle = ws->getUserData()->handle;
                        if (handle)
                        {
                            handle->closed.store(true);
                            handle->wsPtr = nullptr;
                        }

                        std::string msg(message.data(), message.size());

                        resumeWith(
                            state,
                            state->wsCloseRef,
                            [handle, code, msg = std::move(msg)](lua_State* L)
                            {
                                pushServerWebSocket<SSL>(L, handle);
                                lua_pushinteger(L, code);
                                lua_pushlstring(L, msg.data(), msg.size());
                                return 3;
                            }
                        );
                    },
            }
        );
    }

    app->any(
        "/*",
        [state](auto* res, auto* req)
        {
            std::string method = std::string(req->getMethod());
            std::transform(method.begin(), method.end(), method.begin(), ::toupper);
            std::string_view url = req->getFullUrl();
            std::string_view path = url;

            // Split URL into path and query
            size_t queryPos = url.find('?');
            std::string query;
            if (queryPos != std::string::npos)
            {
                path = std::string_view(url.data(), queryPos);
                query = std::string_view(url.data() + queryPos, url.size() - queryPos);
            }

            res->onAborted(
                []()
                {
                    // TODO: handle aborted requests
                }
            );

            std::unique_ptr<std::string> bodyBuffer;
            res->onData(
                [state, res, req, method, path, query, bodyBuffer = std::move(bodyBuffer)](std::string_view data, bool last) mutable
                {
                    if (last)
                    {
                        if (bodyBuffer.get())
                        {
                            bodyBuffer->append(data);
                            processRequest(state, res, req, method, path, query, *bodyBuffer);
                        }
                        else
                        {
                            processRequest(state, res, req, method, path, query, data);
                        }
                    }
                    else
                    {
                        if (bodyBuffer.get())
                        {
                            bodyBuffer->append(data);
                        }
                        else
                        {
                            bodyBuffer = std::make_unique<std::string>(data);
                        }
                    }
                }
            );
        }
    );

    int options = state->reusePort ? LIBUS_LISTEN_DEFAULT : LIBUS_LISTEN_EXCLUSIVE_PORT;

    app->listen(
        state->hostname,
        state->port,
        options,
        [&success](auto* listen_socket)
        {
            success = (listen_socket != nullptr);
        }
    );
}

bool closeServer(int serverId)
{
    if (!serverInstances.contains(serverId) || !serverStates.contains(serverId))
    {
        return false;
    }

    Luau::visit(
        [](auto* appPtr)
        {
            if (appPtr)
                appPtr->close();
        },
        serverStates[serverId]->app
    );
    serverStates[serverId]->running = false;

    Luau::visit(
        [](auto& ptr)
        {
            if (ptr)
                ptr.reset();
        },
        serverInstances[serverId]
    );
    serverStates[serverId] = nullptr;

    return true;
}

int lua_serve(lua_State* L)
{
    uWS::Loop::get(uv_default_loop());

    std::string hostname = "127.0.0.1";
    int port = 3000;
    bool reusePort = false;
    std::optional<uWS::SocketContextOptions> tlsOptions;
    int handlerIndex = 1;
    int websocketIndex = 0;

    // Check if first argument is a table (config) or function (handler)
    if (lua_istable(L, 1))
    {
        lua_getfield(L, 1, "hostname");
        if (lua_isstring(L, -1))
        {
            hostname = lua_tostring(L, -1);
        }
        lua_pop(L, 1);

        lua_getfield(L, 1, "port");
        if (lua_isnumber(L, -1))
        {
            port = lua_tointeger(L, -1);
        }
        lua_pop(L, 1);

        lua_getfield(L, 1, "reuseport");
        if (lua_isboolean(L, -1))
        {
            reusePort = lua_toboolean(L, -1);
        }
        lua_pop(L, 1);

        lua_getfield(L, 1, "tls");
        if (lua_istable(L, -1))
        {
            tlsOptions.emplace();

            lua_getfield(L, -1, "certfilename");
            if (!lua_isstring(L, -1))
            {
                luaL_errorL(L, "tls config requires 'certfilename' (string)");
                return 0;
            }
            tlsOptions->cert_file_name = lua_tostring(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, -1, "keyfilename");
            if (!lua_isstring(L, -1))
            {
                luaL_errorL(L, "tls config requires 'keyfilename' (string)");
                return 0;
            }
            tlsOptions->key_file_name = lua_tostring(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, -1, "passphrase");
            if (lua_isstring(L, -1))
            {
                tlsOptions->passphrase = lua_tostring(L, -1);
            }
            lua_pop(L, 1);

            lua_getfield(L, -1, "cafilename");
            if (lua_isstring(L, -1))
            {
                tlsOptions->ca_file_name = lua_tostring(L, -1);
            }
            lua_pop(L, 1);
        }
        lua_pop(L, 1);

        lua_getfield(L, 1, "handler");
        if (!lua_isfunction(L, -1))
        {
            lua_pop(L, 1);
            luaL_errorL(L, "handler function is required in config table");
            return 0;
        }
        lua_insert(L, -1);
        handlerIndex = lua_gettop(L);

        lua_getfield(L, 1, "websocket");
        if (lua_istable(L, -1))
        {
            websocketIndex = lua_gettop(L);
        }
        else
        {
            lua_pop(L, 1);
        }
    }
    else if (!lua_isfunction(L, 1))
    {
        luaL_errorL(L, "serve requires a handler function or config table");
        return 0;
    }

    Runtime* runtime = getRuntime(L);

    int serverId = nextServerId++;

    auto state = std::make_shared<ServerLoopState>();
    state->runtime = runtime;
    state->hostname = hostname;
    state->port = port;
    state->reusePort = reusePort;

    lua_pushvalue(L, handlerIndex);
    state->handlerRef = std::make_shared<Ref>(L, -1);
    lua_pop(L, 1);

    if (websocketIndex != 0)
    {
        state->hasWebSocket = true;

        lua_getfield(L, websocketIndex, "open");
        if (lua_isfunction(L, -1))
            state->wsOpenRef = std::make_shared<Ref>(L, -1);
        lua_pop(L, 1);

        lua_getfield(L, websocketIndex, "message");
        if (lua_isfunction(L, -1))
            state->wsMessageRef = std::make_shared<Ref>(L, -1);
        lua_pop(L, 1);

        lua_getfield(L, websocketIndex, "close");
        if (lua_isfunction(L, -1))
            state->wsCloseRef = std::make_shared<Ref>(L, -1);
        lua_pop(L, 1);

        lua_getfield(L, websocketIndex, "drain");
        if (lua_isfunction(L, -1))
            state->wsDrainRef = std::make_shared<Ref>(L, -1);
        lua_pop(L, 1);
    }

    uWSApp app;
    bool success = false;

    if (tlsOptions)
    {
        auto ssl_app = std::make_unique<uWS::SSLApp>(*tlsOptions);
        state->app = ssl_app.get();
        setupAppAndListen<true>(ssl_app.get(), state, success);
        app = std::move(ssl_app);
    }
    else
    {
        auto plain_app = std::make_unique<uWS::App>();
        state->app = plain_app.get();
        setupAppAndListen<false>(plain_app.get(), state, success);
        app = std::move(plain_app);
    }

    if (!success)
    {
        luaL_errorL(L, "failed to listen on port %d, is it already in use? consider the reuseport option", port);
        return 0;
    }

    serverInstances[serverId] = std::move(app);
    serverStates[serverId] = state;

    lua_createtable(L, 0, 3);

    lua_pushstring(L, "hostname");
    lua_pushstring(L, hostname.c_str());
    lua_settable(L, -3);

    lua_pushstring(L, "port");
    lua_pushinteger(L, port);
    lua_settable(L, -3);

    lua_pushstring(L, "close");
    lua_pushinteger(L, serverId);
    lua_pushcclosurek(
        L,
        [](lua_State* L) -> int
        {
            int serverId = lua_tointeger(L, lua_upvalueindex(1));

            lua_pushboolean(L, closeServer(serverId));
            return 1;
        },
        "server_close",
        1,
        nullptr
    );
    lua_settable(L, -3);

    // store server table for passing to handler
    state->serverRef = std::make_shared<Ref>(L, -1);

    return 1;
}

} // namespace net

static void initalizeNet(lua_State* L)
{
    luaL_newmetatable(L, "WebSocketHandle");

    lua_pushcfunction(
        L,
        [](lua_State* L)
        {
            const char* index = luaL_checkstring(L, -1);

            if (strcmp(index, "send") == 0)
            {
                lua_pushcfunction(L, net::ws_send, "WebSocketHandle.send");
                return 1;
            }

            if (strcmp(index, "close") == 0)
            {
                lua_pushcfunction(L, net::ws_close, "WebSocketHandle.close");
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
        [](lua_State* L, void* ud)
        {
            std::destroy_at(static_cast<net::WebSocketHandle*>(ud));
        }
    );

    lua_setuserdatametatable(L, kWebSocketHandleTag);

    luaL_newmetatable(L, "ServerWebSocketHandle");

    lua_pushcfunction(
        L,
        [](lua_State* L)
        {
            const char* index = luaL_checkstring(L, -1);

            if (strcmp(index, "send") == 0)
            {
                lua_pushcfunction(L, net::server_ws_send, "ServerWebSocketHandle.send");
                return 1;
            }

            if (strcmp(index, "close") == 0)
            {
                lua_pushcfunction(L, net::server_ws_close, "ServerWebSocketHandle.close");
                return 1;
            }

            return 0;
        },
        "ServerWebSocketHandle.__index"
    );
    lua_setfield(L, -2, "__index");

    lua_pushstring(L, "ServerWebSocketHandle");
    lua_setfield(L, -2, "__type");

    lua_setuserdatadtor(
        L,
        kServerWebSocketHandleTag,
        [](lua_State* L, void* ud)
        {
            std::destroy_at(static_cast<std::shared_ptr<net::ServerWebSocketHandle>*>(ud));
        }
    );

    lua_setuserdatametatable(L, kServerWebSocketHandleTag);
}

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

int luaopen_net(lua_State* L)
{
    globalCurlInit();

    luaL_register(L, "net", net::lib);
    initalizeNet(L);

    return 1;
}

int luteopen_net(lua_State* L)
{
    globalCurlInit();

    lua_createtable(L, 0, std::size(net::lib));

    for (auto& [name, func] : net::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);
    initalizeNet(L);

    return 1;
}
