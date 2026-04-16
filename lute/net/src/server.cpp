#include "lute/net.h"

#include "lute/common.h"
#include "lute/runtime.h"
#include "lute/userdatas.h"

#include "Luau/DenseHash.h"
#include "Luau/Variant.h"

#include "lua.h"
#include "lualib.h"

#include <algorithm>
#include <atomic>
#include <cctype>
#include <cstring>
#include <functional>
#include <limits>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <utility>

#include "App.h"
#include "Loop.h"

namespace net::server
{

using uWSApp = Luau::Variant<std::unique_ptr<uWS::App>, std::unique_ptr<uWS::SSLApp>>;

struct WebSocketPayload
{
    const char* data = nullptr;
    size_t length = 0;
    bool binary = false;
};

static const int kEmptyServerKey = 0;
static Luau::DenseHashMap<int, uWSApp> serverInstances(kEmptyServerKey);
static Luau::DenseHashMap<int, std::shared_ptr<struct ServerLoopState>> serverStates(kEmptyServerKey);
static int nextServerId = 1;
static int kRequestUpgradeKey = 0;
static constexpr unsigned int kWebSocketMaxPayloadLength = 16 * 1024 * 1024;

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
    void* wsPtr = nullptr;
    std::atomic<bool> closed{false};
    std::shared_ptr<Ref> userdataRef;
    int (*sendFn)(void* wsPtr, std::string_view data, bool binary) = nullptr;
    void (*closeFn)(void* wsPtr, uint16_t code, std::string_view message) = nullptr;
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

template <bool SSL>
struct PerSocketData
{
    std::shared_ptr<ServerWebSocketHandle> handle;
};

struct RequestRouteData
{
    std::string method;
    std::string path;
    std::string query;
};

template <typename ReqT>
static RequestRouteData extractRequestRouteData(ReqT* req)
{
    RequestRouteData route;
    route.method = std::string(req->getMethod());
    std::transform(
        route.method.begin(),
        route.method.end(),
        route.method.begin(),
        [](unsigned char ch)
        {
            return char(std::toupper(ch));
        }
    );

    std::string_view url = req->getFullUrl();
    size_t queryPos = url.find('?');
    if (queryPos == std::string::npos)
    {
        route.path.assign(url.data(), url.size());
        return route;
    }

    route.path.assign(url.data(), queryPos);
    route.query.assign(url.data() + queryPos, url.size() - queryPos);
    return route;
}

static void parseQuery(const std::string_view& query, lua_State* L)
{
    lua_createtable(L, 0, 0);
    size_t start = (!query.empty() && query[0] == '?') ? 1 : 0;
    if (start >= query.size())
        return;

    while (start < query.size())
    {
        size_t end = query.find('&', start);
        size_t pairLength = (end == std::string::npos) ? (query.size() - start) : (end - start);
        std::string_view pair = std::string_view(query.data() + start, pairLength);
        size_t eq = pair.find('=');
        if (eq != std::string::npos)
        {
            std::string_view key = std::string_view(pair.data(), eq);
            std::string_view value = uWS::getDecodedQueryValue(key, query);
            lua_pushlstring(L, key.data(), key.size());
            lua_pushlstring(L, value.data(), value.size());
            lua_settable(L, -3);
        }

        if (end == std::string::npos)
            break;

        start = end + 1;
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

    std::string body;
    if (!lua_isnil(L, -1))
    {
        size_t bodyLength = 0;
        const char* bodyData = lua_tolstring(L, -1, &bodyLength);
        if (bodyData)
            body.assign(bodyData, bodyLength);
    }
    lua_pop(L, 1);

    res->end(body);
}

template <typename ResT>
struct HttpYieldContext
{
    ResT* res = nullptr;
    std::atomic<bool> aborted{false};
    std::shared_ptr<Ref> threadRef;
};

template <typename ResT>
static void finishHttpYield(lua_State* L, int status, const std::shared_ptr<HttpYieldContext<ResT>>& ctx)
{
    if (!ctx)
    {
        lua_settop(L, 0);
        return;
    }

    ResT* res = ctx->res;

    if (!res || ctx->aborted.load())
    {
        lua_settop(L, 0);
        return;
    }

    if (status == LUA_OK)
    {
        handleResponse(res, L, -1);
    }
    else
    {
        std::string error = lua_isstring(L, -1) ? lua_tostring(L, -1) : "Server error";
        res->writeStatus("500 Internal Server Error");
        res->end("Server error: " + error);
    }

    ctx->res = nullptr;
    lua_settop(L, 0);
}

static void resumeWith(
    std::shared_ptr<ServerLoopState> state,
    const std::shared_ptr<Ref>& callback,
    std::function<int(lua_State*)> argPusher
)
{
    if (!callback)
        return;

    state->runtime->scheduleLuauCallback(callback, std::move(argPusher));
}

template <bool SSL>
static bool performWebSocketUpgrade(
    uWS::HttpResponse<SSL>* res,
    uWS::HttpRequest* req,
    us_socket_context_t* context
)
{
    std::string_view key = req->getHeader("sec-websocket-key");
    std::string_view protocol = req->getHeader("sec-websocket-protocol");
    std::string_view extensions = req->getHeader("sec-websocket-extensions");

    if (key.empty())
        return false;

    PerSocketData<SSL> userData;
    res->template upgrade<PerSocketData<SSL>>(std::move(userData), key, protocol, extensions, context);
    return true;
}

static int server_upgrade_noop(lua_State* L)
{
    lua_pushboolean(L, 0);
    return 1;
}

static int server_upgrade(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TTABLE);
    luaL_checktype(L, 2, LUA_TTABLE);

    if (!lua_getmetatable(L, 2))
    {
        lua_pushboolean(L, 0);
        return 1;
    }

    lua_pushlightuserdata(L, &kRequestUpgradeKey);
    lua_rawget(L, -2);
    if (!lua_isfunction(L, -1))
    {
        lua_pop(L, 2);
        lua_pushboolean(L, 0);
        return 1;
    }

    lua_call(L, 0, 1);
    lua_remove(L, -2);
    return 1;
}

template <bool SSL>
static int server_upgrade_do(lua_State* L)
{
    auto* res = static_cast<uWS::HttpResponse<SSL>*>(lua_touserdata(L, lua_upvalueindex(1)));
    auto* req = static_cast<uWS::HttpRequest*>(lua_touserdata(L, lua_upvalueindex(2)));
    auto* context = static_cast<us_socket_context_t*>(lua_touserdata(L, lua_upvalueindex(3)));
    auto* upgradedPtr = static_cast<bool*>(lua_touserdata(L, lua_upvalueindex(4)));

    if (!res || !req || !context || !upgradedPtr)
    {
        lua_pushboolean(L, 0);
        return 1;
    }

    bool upgraded = performWebSocketUpgrade<SSL>(res, req, context);
    *upgradedPtr = upgraded;
    lua_pushboolean(L, upgraded);
    return 1;
}

template <bool SSL>
static int wsSendImpl(void* wsPtr, std::string_view data, bool binary)
{
    auto* ws = static_cast<uWS::WebSocket<SSL, true, PerSocketData<SSL>>*>(wsPtr);
    auto status = ws->send(data, binary ? uWS::OpCode::BINARY : uWS::OpCode::TEXT);

    if (status == decltype(status)::BACKPRESSURE)
        return -1;

    if (status == decltype(status)::DROPPED)
        return 0;

    return int(data.size() > 0 ? data.size() : 1);
}

template <bool SSL>
static void wsCloseImpl(void* wsPtr, uint16_t code, std::string_view message)
{
    auto* ws = static_cast<uWS::WebSocket<SSL, true, PerSocketData<SSL>>*>(wsPtr);
    ws->end(int(code), message);
}

static int server_ws_send(lua_State* L)
{
    if (lua_gettop(L) != 2)
        luaL_errorL(L, "websocket send expects exactly 1 payload argument");

    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handlePtr =
        static_cast<std::shared_ptr<ServerWebSocketHandle>*>(lua_touserdatatagged(L, 1, kServerWebSocketHandleTag));
    if (!handlePtr || !(*handlePtr) || (*handlePtr)->closed.load())
    {
        lua_pushinteger(L, 0);
        return 1;
    }

    WebSocketPayload payload = extractWebSocketPayload(L, 2);

    int result = 0;
    if (!(*handlePtr)->closed.load() && (*handlePtr)->wsPtr && (*handlePtr)->sendFn)
        result = (*handlePtr)->sendFn((*handlePtr)->wsPtr, std::string_view(payload.data, payload.length), payload.binary);

    lua_pushinteger(L, result);
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
    if (!lua_isnoneornil(L, 2))
    {
        code = int(luaL_checkinteger(L, 2));
        if (code < 0 || code > std::numeric_limits<uint16_t>::max())
            luaL_errorL(L, "invalid websocket close code %d", code);
    }

    std::string message;
    if (!lua_isnoneornil(L, 3))
    {
        size_t messageLength = 0;
        const char* messageData = luaL_checklstring(L, 3, &messageLength);
        message.assign(messageData, messageLength);
    }

    if (!(*handlePtr)->closed.load() && (*handlePtr)->wsPtr && (*handlePtr)->closeFn)
    {
        (*handlePtr)->closeFn((*handlePtr)->wsPtr, uint16_t(code), message);
    }

    return 0;
}

static void pushServerWebSocket(
    lua_State* L,
    const std::shared_ptr<ServerWebSocketHandle>& handle,
    const std::shared_ptr<Ref>& retainedRef = nullptr
)
{
    if (retainedRef)
    {
        retainedRef->push(L);
        return;
    }

    if (handle->userdataRef)
    {
        handle->userdataRef->push(L);
        return;
    }

    auto* storage =
        new (static_cast<std::shared_ptr<ServerWebSocketHandle>*>(lua_newuserdatataggedwithmetatable(
            L,
            sizeof(std::shared_ptr<ServerWebSocketHandle>),
            kServerWebSocketHandleTag
        ))) std::shared_ptr<ServerWebSocketHandle>(handle);
    (void)storage;
    handle->userdataRef = std::make_shared<Ref>(L, -1);
}

struct HandlerThread
{
    lua_State* L = nullptr;
    std::shared_ptr<Ref> threadRef;
};

static HandlerThread createHandlerThread(Runtime* runtime)
{
    LUTE_ASSERT(runtime);

    lua_State* L = lua_newthread(runtime->GL);
    luaL_sandboxthread(L);
    lua_checkstack(L, 64);
    std::shared_ptr<Ref> threadRef = getRefForThread(L);
    lua_pop(runtime->GL, 1);
    return {L, std::move(threadRef)};
}

template <typename ReqT, typename PushUpvalues>
static void pushRequestTable(
    lua_State* L,
    ReqT* req,
    const RequestRouteData& route,
    std::string_view body,
    lua_CFunction upgradeFn,
    int nUpvalues,
    PushUpvalues pushUpvalues
)
{
    lua_createtable(L, 0, 5);

    lua_pushstring(L, "method");
    lua_pushstring(L, route.method.c_str());
    lua_settable(L, -3);

    lua_pushstring(L, "path");
    lua_pushlstring(L, route.path.data(), route.path.size());
    lua_settable(L, -3);

    lua_pushstring(L, "query");
    parseQuery(route.query, L);
    lua_settable(L, -3);

    lua_pushstring(L, "headers");
    parseHeaders(req, L);
    lua_settable(L, -3);

    lua_pushstring(L, "body");
    lua_pushlstring(L, body.data(), body.size());
    lua_settable(L, -3);

    int requestIndex = lua_absindex(L, -1);
    lua_createtable(L, 0, 1);
    lua_pushlightuserdata(L, &kRequestUpgradeKey);
    pushUpvalues(L);
    lua_pushcclosure(L, upgradeFn, "request.upgrade", nUpvalues);
    lua_rawset(L, -3);
    lua_setmetatable(L, requestIndex);
}

template <typename PushUpvalues>
static void pushServerTable(
    lua_State* L,
    const std::shared_ptr<Ref>& serverRef,
    lua_CFunction upgradeFn,
    int nUpvalues,
    PushUpvalues pushUpvalues
)
{
    if (serverRef)
        serverRef->push(L);
    else
        lua_newtable(L);

    int serverBaseIndex = lua_absindex(L, -1);

    lua_createtable(L, 0, 1);
    lua_createtable(L, 0, 1);
    lua_pushvalue(L, serverBaseIndex);
    lua_setfield(L, -2, "__index");
    lua_setmetatable(L, -2);

    pushUpvalues(L);
    lua_pushcclosure(L, upgradeFn, "server.upgrade", nUpvalues);
    lua_setfield(L, -2, "upgrade");

    lua_remove(L, serverBaseIndex);
}

template <typename ReqT>
static HandlerThread prepareHttpHandlerThread(
    const std::shared_ptr<ServerLoopState>& state,
    ReqT* req,
    const RequestRouteData& route,
    std::string_view body
)
{
    LUTE_ASSERT(state);
    LUTE_ASSERT(state->runtime);
    LUTE_ASSERT(state->handlerRef);

    HandlerThread thread = createHandlerThread(state->runtime);
    lua_State* L = thread.L;

    // `lua_resume(L, nullptr, 2)` expects the stack shape `[handler, request, server]`.
    state->handlerRef->push(L);
    pushRequestTable(L, req, route, body, server_upgrade_noop, 0, [](lua_State*) {});
    pushServerTable(L, state->serverRef, server_upgrade_noop, 0, [](lua_State*) {});
    return thread;
}

template <bool SSL>
static HandlerThread prepareUpgradeHandlerThread(
    const std::shared_ptr<ServerLoopState>& state,
    uWS::HttpResponse<SSL>* res,
    uWS::HttpRequest* req,
    us_socket_context_t* context,
    const RequestRouteData& route,
    bool& upgraded
)
{
    LUTE_ASSERT(state);
    LUTE_ASSERT(state->runtime);
    LUTE_ASSERT(state->handlerRef);

    auto pushUpgradeUpvalues = [res, req, context, &upgraded](lua_State* L)
    {
        lua_pushlightuserdata(L, res);
        lua_pushlightuserdata(L, req);
        lua_pushlightuserdata(L, context);
        lua_pushlightuserdata(L, &upgraded);
    };

    HandlerThread thread = createHandlerThread(state->runtime);
    lua_State* L = thread.L;

    // `lua_resume(L, nullptr, 2)` expects the stack shape `[handler, request, server]`.
    state->handlerRef->push(L);
    pushRequestTable(L, req, route, std::string_view(""), server_upgrade_do<SSL>, 4, pushUpgradeUpvalues);
    pushServerTable(L, state->serverRef, server_upgrade_do<SSL>, 4, pushUpgradeUpvalues);
    return thread;
}

template <typename ResT, typename ReqT>
static void processRequest(
    const std::shared_ptr<ServerLoopState>& state,
    ResT* res,
    ReqT* req,
    const RequestRouteData& route,
    std::string_view body
)
{
    if (!state->handlerRef)
    {
        res->writeStatus("404 Not Found");
        res->end("No handler configured");
        return;
    }

    HandlerThread thread = prepareHttpHandlerThread(state, req, route, body);
    lua_State* L = thread.L;
    int status = lua_resume(L, nullptr, 2);
    if (status == LUA_YIELD)
    {
        auto ctx = std::make_shared<HttpYieldContext<ResT>>();
        ctx->res = res;
        ctx->threadRef = std::move(thread.threadRef);

        res->onAborted(
            [ctx]()
            {
                ctx->aborted.store(true);
                ctx->res = nullptr;
            }
        );

        ThreadCompletionHandler completion;
        completion.onFinish = [ctx](lua_State* L, int completionStatus)
        {
            finishHttpYield<ResT>(L, completionStatus, ctx);
        };

        state->runtime->addThreadCompletionHandler(L, std::move(completion));
        lua_settop(L, 0);
        return;
    }

    if (status != LUA_OK)
    {
        std::string error = lua_isstring(L, -1) ? lua_tostring(L, -1) : "Server error";
        lua_pop(L, 1);

        res->writeStatus("500 Internal Server Error");
        res->end("Server error: " + error);
        return;
    }

    handleResponse(res, L, -1);
    lua_pop(L, 1);
}

template <bool SSL, typename AppT>
static void installWebSocketRoutes(AppT* app, const std::shared_ptr<ServerLoopState>& state)
{
    if (!state->hasWebSocket)
        return;

    typename uWS::TemplatedApp<SSL>::template WebSocketBehavior<PerSocketData<SSL>> behavior{};
    behavior.maxPayloadLength = kWebSocketMaxPayloadLength;
    behavior.upgrade =
        [state](auto* res, auto* req, auto* context)
        {
            if (!state->handlerRef)
            {
                if (!performWebSocketUpgrade<SSL>(res, req, context))
                {
                    res->writeStatus("426 Upgrade Required");
                    res->end("WebSocket upgrade required");
                }
                return;
            }

            RequestRouteData route = extractRequestRouteData(req);
            bool upgraded = false;
            HandlerThread thread = prepareUpgradeHandlerThread<SSL>(state, res, req, context, route, upgraded);
            lua_State* L = thread.L;
            int status = lua_resume(L, nullptr, 2);

            if (status == LUA_YIELD)
            {
                lua_resetthread(L);

                if (!upgraded)
                {
                    res->writeStatus("500 Internal Server Error");
                    res->end("upgrade handler cannot yield");
                }
                return;
            }

            if (status != LUA_OK)
            {
                std::string error = lua_isstring(L, -1) ? lua_tostring(L, -1) : "Server error";
                if (!upgraded)
                {
                    res->writeStatus("500 Internal Server Error");
                    res->end("Server error: " + error);
                }
                lua_pop(L, 1);
                return;
            }

            if (!upgraded)
                handleResponse(res, L, -1);

            lua_pop(L, 1);
        };
    behavior.open =
        [state](auto* ws)
        {
            auto* data = ws->getUserData();
            data->handle = std::make_shared<ServerWebSocketHandle>();
            data->handle->wsPtr = ws;
            data->handle->sendFn = &wsSendImpl<SSL>;
            data->handle->closeFn = &wsCloseImpl<SSL>;

            resumeWith(
                state,
                state->wsOpenRef,
                [handle = data->handle](lua_State* L)
                {
                    pushServerWebSocket(L, handle);
                    return 1;
                }
            );
        };
    behavior.message =
        [state](auto* ws, std::string_view message, uWS::OpCode opCode)
        {
            auto handle = ws->getUserData()->handle;
            std::string payload(message.data(), message.size());
            bool binary = (opCode == uWS::OpCode::BINARY);

            resumeWith(
                state,
                state->wsMessageRef,
                [handle, payload = std::move(payload), binary](lua_State* L)
                {
                    pushServerWebSocket(L, handle);
                    if (binary)
                    {
                        void* buf = lua_newbuffer(L, payload.size());
                        if (!payload.empty())
                            memcpy(buf, payload.data(), payload.size());
                    }
                    else
                    {
                        lua_pushlstring(L, payload.data(), payload.size());
                    }
                    return 2;
                }
            );
        };
    behavior.drain =
        [state](auto* ws)
        {
            auto handle = ws->getUserData()->handle;

            resumeWith(
                state,
                state->wsDrainRef,
                [handle](lua_State* L)
                {
                    pushServerWebSocket(L, handle);
                    return 1;
                }
            );
        };
    behavior.close =
        [state](auto* ws, int code, std::string_view message)
        {
            auto handle = ws->getUserData()->handle;
            std::shared_ptr<Ref> userdataRef;
            if (handle)
            {
                handle->closed.store(true);
                handle->wsPtr = nullptr;
                userdataRef = std::move(handle->userdataRef);
            }

            std::string payload(message.data(), message.size());

            resumeWith(
                state,
                state->wsCloseRef,
                [handle, userdataRef = std::move(userdataRef), code, payload = std::move(payload)](lua_State* L)
                {
                    pushServerWebSocket(L, handle, userdataRef);
                    lua_pushinteger(L, code);
                    lua_pushlstring(L, payload.data(), payload.size());
                    return 3;
                }
            );
        };

    app->template ws<PerSocketData<SSL>>("/*", std::move(behavior));
}

template <typename AppT>
static void installHttpRoutes(AppT* app, const std::shared_ptr<ServerLoopState>& state)
{
    app->any(
        "/*",
        [state](auto* res, auto* req)
        {
            RequestRouteData route = extractRequestRouteData(req);

            res->onAborted(
                []()
                {
                    // TODO: handle aborted requests
                }
            );

            std::unique_ptr<std::string> bodyBuffer;
            res->onData(
                [state, res, req, route = std::move(route), bodyBuffer = std::move(bodyBuffer)](
                    std::string_view data,
                    bool last
                ) mutable
                {
                    if (last)
                    {
                        if (bodyBuffer.get())
                        {
                            bodyBuffer->append(data);
                            processRequest(state, res, req, route, *bodyBuffer);
                        }
                        else
                        {
                            processRequest(state, res, req, route, data);
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
}

template <bool SSL, typename AppT>
static void listenApp(AppT* app, const std::shared_ptr<ServerLoopState>& state, bool& success)
{
    int options = state->reusePort ? LIBUS_LISTEN_DEFAULT : LIBUS_LISTEN_EXCLUSIVE_PORT;

    app->listen(
        state->hostname,
        state->port,
        options,
        [state, &success](auto* listen_socket)
        {
            success = (listen_socket != nullptr);
            if (listen_socket)
                state->port = us_socket_local_port(SSL, (struct us_socket_t*)listen_socket);
        }
    );
}

static bool closeServer(int serverId)
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

int serve(lua_State* L)
{
    uWS::Loop::get(getRuntimeLoop(L));

    std::string hostname = "127.0.0.1";
    int port = 3000;
    bool reusePort = false;
    std::optional<uWS::SocketContextOptions> tlsOptions;
    int handlerIndex = 0;
    int websocketIndex = 0;

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
        if (lua_isfunction(L, -1))
        {
            handlerIndex = lua_gettop(L);
        }
        else
        {
            lua_pop(L, 1);
        }

        lua_getfield(L, 1, "websocket");
        if (lua_istable(L, -1))
        {
            websocketIndex = lua_gettop(L);
        }
        else
        {
            lua_pop(L, 1);
        }

        if (handlerIndex == 0 && websocketIndex == 0)
        {
            luaL_errorL(L, "config table requires a handler function, websocket config, or both");
            return 0;
        }
    }
    else if (!lua_isfunction(L, 1))
    {
        luaL_errorL(L, "serve requires a handler function or config table");
        return 0;
    }
    else
    {
        handlerIndex = 1;
    }

    Runtime* runtime = getRuntime(L);

    int serverId = nextServerId++;

    auto state = std::make_shared<ServerLoopState>();
    state->runtime = runtime;
    state->hostname = hostname;
    state->port = port;
    state->reusePort = reusePort;

    if (handlerIndex != 0)
    {
        lua_pushvalue(L, handlerIndex);
        state->handlerRef = std::make_shared<Ref>(L, -1);
        lua_pop(L, 1);
    }

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
        installWebSocketRoutes<true>(ssl_app.get(), state);
        installHttpRoutes(ssl_app.get(), state);
        listenApp<true>(ssl_app.get(), state, success);
        app = std::move(ssl_app);
    }
    else
    {
        auto plain_app = std::make_unique<uWS::App>();
        state->app = plain_app.get();
        installWebSocketRoutes<false>(plain_app.get(), state);
        installHttpRoutes(plain_app.get(), state);
        listenApp<false>(plain_app.get(), state, success);
        app = std::move(plain_app);
    }

    if (!success)
    {
        luaL_errorL(L, "failed to listen on port %d, is it already in use? consider the reuseport option", port);
        return 0;
    }

    serverInstances[serverId] = std::move(app);
    serverStates[serverId] = state;

    lua_createtable(L, 0, 4);

    lua_pushstring(L, "hostname");
    lua_pushstring(L, hostname.c_str());
    lua_settable(L, -3);

    lua_pushstring(L, "port");
    lua_pushinteger(L, state->port);
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

    lua_pushstring(L, "upgrade");
    lua_pushcfunction(L, server_upgrade, "server_upgrade");
    lua_settable(L, -3);

    state->serverRef = std::make_shared<Ref>(L, -1);

    return 1;
}

} // namespace net::server

static void initializeNetServer(lua_State* L)
{
    luaL_newmetatable(L, "ServerWebSocketHandle");

    lua_pushcfunction(
        L,
        [](lua_State* L)
        {
            const char* index = luaL_checkstring(L, -1);

            if (strcmp(index, "send") == 0)
            {
                lua_pushcfunction(L, net::server::server_ws_send, "ServerWebSocketHandle.send");
                return 1;
            }

            if (strcmp(index, "close") == 0)
            {
                lua_pushcfunction(L, net::server::server_ws_close, "ServerWebSocketHandle.close");
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
        [](lua_State*, void* ud)
        {
            std::destroy_at(static_cast<std::shared_ptr<net::server::ServerWebSocketHandle>*>(ud));
        }
    );

    lua_setuserdatametatable(L, kServerWebSocketHandleTag);
}

const char* const NetServer::properties[] = {nullptr};

const luaL_Reg NetServer::lib[] = {
    {"serve", net::server::serve},
    {nullptr, nullptr},
};

int NetServer::pushLibrary(lua_State* L)
{
    initializeNetServer(L);

    lua_createtable(L, 0, std::size(NetServer::lib));

    for (auto& [name, func] : NetServer::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    return 1;
}

int luteopen_net_server(lua_State* L)
{
    return NetServer::pushLibrary(L);
}
