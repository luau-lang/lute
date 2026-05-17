#include "lute/common.h"
#include "lute/net.h"
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
#include <vector>

#include "App.h"
#include "Loop.h"
#include "wscommon.h"

namespace net::server
{

using uWSApp = Luau::Variant<std::unique_ptr<uWS::App>, std::unique_ptr<uWS::SSLApp>>;

static const int kEmptyServerKey = 0;
static Luau::DenseHashMap<int, uWSApp> serverInstances(kEmptyServerKey);
static Luau::DenseHashMap<int, std::shared_ptr<struct ServerLoopState>> serverStates(kEmptyServerKey);
static int nextServerId = 1;
static int kRequestUpgradeKey = 0;
static constexpr unsigned int kWebSocketMaxPayloadLength = 16 * 1024 * 1024;

enum class RouteHandlerKind
{
    Function,
    StaticResponse,
};

struct RouteContext
{
    std::string pattern;
    std::string method;
    RouteHandlerKind kind = RouteHandlerKind::Function;
    std::shared_ptr<Ref> ref;
    std::string staticStatus;
    std::vector<std::pair<std::string, std::string>> staticHeaders;
    std::string staticBody;
    std::vector<std::string> paramNames;
};

using MatchedParams = std::vector<std::pair<std::string, std::string>>;

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
    std::vector<std::shared_ptr<RouteContext>> routes;
    bool hasWebSocket = false;
    std::string hostname;
    int port;
    bool reusePort = false;
};

template<bool SSL>
struct PerSocketData;

struct ServerWebSocketHandle
{
    void* wsPtr = nullptr;
    std::atomic<bool> closed{false};
    std::shared_ptr<Ref> userdataRef;
    int (*sendFn)(void* wsPtr, std::string_view data, bool binary) = nullptr;
    void (*closeFn)(void* wsPtr, uint16_t code, std::string_view message) = nullptr;
};

template<bool SSL>
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

using RequestHeaders = std::vector<std::pair<std::string, std::string>>;

template<typename ReqT>
static RequestHeaders extractRequestHeaders(ReqT* req)
{
    RequestHeaders headers;
    for (const auto& header : *req)
    {
        headers.emplace_back(std::string(header.first), std::string(header.second));
    }
    return headers;
}

template<typename ReqT>
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

static void pushHeadersTable(const RequestHeaders& headers, lua_State* L)
{
    lua_createtable(L, 0, int(headers.size()));
    for (const auto& [key, value] : headers)
    {
        lua_pushlstring(L, key.data(), key.size());
        lua_pushlstring(L, value.data(), value.size());
        lua_settable(L, -3);
    }
}

static constexpr const char* kHttpMethodNames[] = {"GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS", "CONNECT", "TRACE"};

struct ParsedPattern
{
    std::vector<std::string> paramNames;
};

static std::string getStatusText(int status)
{
    switch (status)
    {
    case 200:
        return "200 OK";
    case 201:
        return "201 Created";
    case 204:
        return "204 No Content";
    case 400:
        return "400 Bad Request";
    case 401:
        return "401 Unauthorized";
    case 403:
        return "403 Forbidden";
    case 404:
        return "404 Not Found";
    case 500:
        return "500 Internal Server Error";
    default:
        return std::to_string(status) + " Status";
    }
}

static void cacheStaticResponse(RouteContext& ctx, lua_State* L, int responseIndex)
{
    int absIndex = lua_absindex(L, responseIndex);

    if (lua_isstring(L, absIndex))
    {
        size_t bodyLength = 0;
        const char* bodyData = lua_tolstring(L, absIndex, &bodyLength);
        ctx.staticStatus = "200 OK";
        ctx.staticHeaders.emplace_back("Content-Type", "text/html");
        if (bodyData)
            ctx.staticBody.assign(bodyData, bodyLength);
        return;
    }

    lua_getfield(L, absIndex, "status");
    int status = lua_isnumber(L, -1) ? lua_tointeger(L, -1) : 200;
    lua_pop(L, 1);
    ctx.staticStatus = getStatusText(status);

    lua_getfield(L, absIndex, "headers");
    if (lua_istable(L, -1))
    {
        lua_pushnil(L);
        while (lua_next(L, -2))
        {
            if (lua_type(L, -2) == LUA_TSTRING && lua_isstring(L, -1))
            {
                size_t headerNameLength = 0;
                size_t headerValueLength = 0;
                const char* headerName = lua_tolstring(L, -2, &headerNameLength);
                const char* headerValue = lua_tolstring(L, -1, &headerValueLength);
                ctx.staticHeaders.emplace_back(
                    std::string(headerName, headerNameLength),
                    std::string(headerValue, headerValueLength)
                );
            }
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);

    lua_getfield(L, absIndex, "body");
    if (!lua_isnil(L, -1))
    {
        size_t bodyLength = 0;
        const char* bodyData = lua_tolstring(L, -1, &bodyLength);
        if (bodyData)
            ctx.staticBody.assign(bodyData, bodyLength);
    }
    lua_pop(L, 1);
}

template<typename ResT>
static void replayStaticResponse(ResT* res, const RouteContext& ctx)
{
    res->writeStatus(ctx.staticStatus);
    for (const auto& [name, value] : ctx.staticHeaders)
        res->writeHeader(name, value);
    res->end(ctx.staticBody);
}

static ParsedPattern parsePattern(lua_State* L, std::string_view pattern)
{
    if (pattern.empty() || pattern[0] != '/')
        luaL_errorL(L, "route pattern '%.*s' must start with '/'", int(pattern.size()), pattern.data());

    ParsedPattern info;
    std::string_view body = pattern;
    body.remove_prefix(1);

    size_t start = 0;
    while (start < body.size())
    {
        size_t end = body.find('/', start);
        std::string_view seg = (end == std::string_view::npos) ? body.substr(start) : body.substr(start, end - start);

        if (!seg.empty() && seg[0] == ':')
        {
            if (seg.size() < 2)
                luaL_errorL(L, "route pattern '%.*s' has an empty parameter name", int(pattern.size()), pattern.data());

            std::string paramName(seg.substr(1));
            if (std::find(info.paramNames.begin(), info.paramNames.end(), paramName) != info.paramNames.end())
                luaL_errorL(L, "route pattern '%.*s' has duplicate parameter name '%s'", int(pattern.size()), pattern.data(), paramName.c_str());

            info.paramNames.push_back(std::move(paramName));
        }

        if (end == std::string_view::npos)
            break;
        start = end + 1;
    }

    return info;
}

static std::shared_ptr<RouteContext> makeRouteContext(
    lua_State* L,
    int valueIndex,
    const std::string& pattern,
    const char* method,
    const ParsedPattern& info
)
{
    auto ctx = std::make_shared<RouteContext>();
    ctx->pattern = pattern;
    ctx->method = method;
    ctx->paramNames = info.paramNames;

    int absIndex = lua_absindex(L, valueIndex);
    if (lua_isfunction(L, absIndex))
        ctx->kind = RouteHandlerKind::Function;
    else if (lua_isstring(L, absIndex) || lua_istable(L, absIndex))
        ctx->kind = RouteHandlerKind::StaticResponse;
    else
        luaL_errorL(L, "route handler must be a function, string, or response table");

    if (ctx->kind == RouteHandlerKind::Function)
    {
        lua_pushvalue(L, absIndex);
        ctx->ref = std::make_shared<Ref>(L, -1);
        lua_pop(L, 1);
    }
    else
    {
        cacheStaticResponse(*ctx, L, absIndex);
    }
    return ctx;
}

static bool tableHasAnyHttpMethodKey(lua_State* L, int tableIndex)
{
    int absIndex = lua_absindex(L, tableIndex);
    for (const char* m : kHttpMethodNames)
    {
        lua_getfield(L, absIndex, m);
        bool present = !lua_isnil(L, -1);
        lua_pop(L, 1);
        if (present)
            return true;
    }
    return false;
}

static void parseRoutesTable(lua_State* L, int tableIndex, ServerLoopState& state)
{
    int absIndex = lua_absindex(L, tableIndex);
    lua_pushnil(L);
    while (lua_next(L, absIndex))
    {
        if (lua_type(L, -2) != LUA_TSTRING)
        {
            luaL_errorL(L, "route keys must be strings, got %s", luaL_typename(L, -2));
        }

        size_t keyLen = 0;
        const char* keyData = lua_tolstring(L, -2, &keyLen);
        std::string pattern(keyData, keyLen);
        ParsedPattern info = parsePattern(L, pattern);

        int valueType = lua_type(L, -1);
        if (valueType == LUA_TFUNCTION || valueType == LUA_TSTRING)
        {
            state.routes.push_back(makeRouteContext(L, -1, pattern, "*", info));
        }
        else if (valueType == LUA_TTABLE && tableHasAnyHttpMethodKey(L, -1))
        {
            int valueIdx = lua_gettop(L);
            for (const char* m : kHttpMethodNames)
            {
                lua_getfield(L, valueIdx, m);
                if (!lua_isnil(L, -1))
                    state.routes.push_back(makeRouteContext(L, -1, pattern, m, info));
                lua_pop(L, 1);
            }
        }
        else if (valueType == LUA_TTABLE)
        {
            state.routes.push_back(makeRouteContext(L, -1, pattern, "*", info));
        }
        else
        {
            luaL_errorL(L, "route '%s' must map to a function, response table, or method-dispatch table", pattern.c_str());
        }

        lua_pop(L, 1);
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

    res->writeStatus(getStatusText(status));

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

template<typename ResT>
struct HttpYieldContext
{
    ResT* res = nullptr;
    std::atomic<bool> aborted{false};
    std::shared_ptr<Ref> threadRef;
};

template<typename ResT>
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

static void resumeWith(std::shared_ptr<ServerLoopState> state, const std::shared_ptr<Ref>& callback, std::function<int(lua_State*)> argPusher)
{
    if (!callback)
        return;

    state->runtime->scheduleLuauCallback(callback, std::move(argPusher));
}

template<bool SSL>
static bool performWebSocketUpgrade(uWS::HttpResponse<SSL>* res, uWS::HttpRequest* req, us_socket_context_t* context)
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

template<bool SSL>
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

template<bool SSL>
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

template<bool SSL>
static void wsCloseImpl(void* wsPtr, uint16_t code, std::string_view message)
{
    auto* ws = static_cast<uWS::WebSocket<SSL, true, PerSocketData<SSL>>*>(wsPtr);
    ws->end(int(code), message);
}

static int server_ws_send(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handlePtr = static_cast<std::shared_ptr<ServerWebSocketHandle>*>(lua_touserdatatagged(L, 1, kServerWebSocketHandleTag));
    if (!handlePtr || !(*handlePtr) || (*handlePtr)->closed.load())
    {
        lua_pushinteger(L, 0);
        return 1;
    }

    WebSocketPayload payload = checkWebSocketPayload(L, 2);

    int result = 0;
    if (!(*handlePtr)->closed.load() && (*handlePtr)->wsPtr && (*handlePtr)->sendFn)
        result = (*handlePtr)->sendFn((*handlePtr)->wsPtr, std::string_view(payload.data, payload.length), payload.binary);

    lua_pushinteger(L, result);
    return 1;
}

static int server_ws_close(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TUSERDATA);
    auto* handlePtr = static_cast<std::shared_ptr<ServerWebSocketHandle>*>(lua_touserdatatagged(L, 1, kServerWebSocketHandleTag));
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

static void pushServerWebSocket(lua_State* L, const std::shared_ptr<ServerWebSocketHandle>& handle, const std::shared_ptr<Ref>& retainedRef = nullptr)
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

    auto* storage = new (static_cast<std::shared_ptr<ServerWebSocketHandle>*>(
        lua_newuserdatataggedwithmetatable(L, sizeof(std::shared_ptr<ServerWebSocketHandle>), kServerWebSocketHandleTag)
    )) std::shared_ptr<ServerWebSocketHandle>(handle);
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

template<typename PushUpvalues>
static void pushRequestTable(
    lua_State* L,
    const RequestHeaders& headers,
    const RequestRouteData& route,
    std::string_view body,
    lua_CFunction upgradeFn,
    int nUpvalues,
    PushUpvalues pushUpvalues,
    const MatchedParams* params = nullptr
)
{
    lua_createtable(L, 0, 6);

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
    pushHeadersTable(headers, L);
    lua_settable(L, -3);

    lua_pushstring(L, "body");
    lua_pushlstring(L, body.data() != nullptr ? body.data() : "", body.size());
    lua_settable(L, -3);

    lua_pushstring(L, "params");
    if (params && !params->empty())
    {
        lua_createtable(L, 0, int(params->size()));
        for (const auto& [k, v] : *params)
        {
            lua_pushlstring(L, k.data(), k.size());
            lua_pushlstring(L, v.data(), v.size());
            lua_settable(L, -3);
        }
    }
    else
    {
        lua_createtable(L, 0, 0);
    }
    lua_settable(L, -3);

    int requestIndex = lua_absindex(L, -1);
    lua_createtable(L, 0, 1);
    lua_pushlightuserdata(L, &kRequestUpgradeKey);
    pushUpvalues(L);
    lua_pushcclosure(L, upgradeFn, "request.upgrade", nUpvalues);
    lua_rawset(L, -3);
    lua_setmetatable(L, requestIndex);
}

template<typename PushUpvalues>
static void pushServerTable(lua_State* L, const std::shared_ptr<Ref>& serverRef, lua_CFunction upgradeFn, int nUpvalues, PushUpvalues pushUpvalues)
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

static HandlerThread prepareHttpHandlerThread(
    const std::shared_ptr<ServerLoopState>& state,
    const std::shared_ptr<Ref>& handlerRef,
    const RequestHeaders& headers,
    const RequestRouteData& route,
    std::string_view body,
    const MatchedParams* params
)
{
    LUTE_ASSERT(state);
    LUTE_ASSERT(state->runtime);
    LUTE_ASSERT(handlerRef);

    HandlerThread thread = createHandlerThread(state->runtime);
    lua_State* L = thread.L;

    // `lua_resume(L, nullptr, 2)` expects the stack shape `[handler, request, server]`.
    handlerRef->push(L);
    pushRequestTable(L, headers, route, body, server_upgrade_noop, 0, [](lua_State*) {}, params);
    pushServerTable(L, state->serverRef, server_upgrade_noop, 0, [](lua_State*) {});
    return thread;
}

template<bool SSL>
static HandlerThread prepareUpgradeHandlerThread(
    const std::shared_ptr<ServerLoopState>& state,
    uWS::HttpResponse<SSL>* res,
    uWS::HttpRequest* req,
    us_socket_context_t* context,
    const RequestHeaders& headers,
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
    pushRequestTable(L, headers, route, std::string_view(""), server_upgrade_do<SSL>, 4, pushUpgradeUpvalues);
    pushServerTable(L, state->serverRef, server_upgrade_do<SSL>, 4, pushUpgradeUpvalues);
    return thread;
}

template<typename ResT>
static void processRequest(
    const std::shared_ptr<ServerLoopState>& state,
    const std::shared_ptr<RouteContext>& routeCtx,
    ResT* res,
    const RequestHeaders& headers,
    const RequestRouteData& route,
    std::string_view body,
    const MatchedParams* params
)
{
    std::shared_ptr<Ref> handlerRef;
    if (routeCtx)
    {
        handlerRef = routeCtx->ref;
    }
    else if (state->handlerRef)
    {
        handlerRef = state->handlerRef;
    }
    else
    {
        res->writeStatus("404 Not Found");
        res->end("Not Found");
        return;
    }

    HandlerThread thread = prepareHttpHandlerThread(state, handlerRef, headers, route, body, params);
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

template<bool SSL, typename AppT>
static void installWebSocketRoutes(AppT* app, const std::shared_ptr<ServerLoopState>& state)
{
    if (!state->hasWebSocket)
        return;

    typename uWS::TemplatedApp<SSL>::template WebSocketBehavior<PerSocketData<SSL>> behavior{};
    behavior.maxPayloadLength = kWebSocketMaxPayloadLength;
    behavior.upgrade = [state](auto* res, auto* req, auto* context)
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
        RequestHeaders headers = extractRequestHeaders(req);
        bool upgraded = false;
        HandlerThread thread = prepareUpgradeHandlerThread<SSL>(state, res, req, context, headers, route, upgraded);
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
    behavior.open = [state](auto* ws)
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
    behavior.message = [state](auto* ws, std::string_view message, uWS::OpCode opCode)
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
    behavior.drain = [state](auto* ws)
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
    behavior.close = [state](auto* ws, int code, std::string_view message)
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

template<typename ResT, typename ReqT>
static void onRouteRequest(
    const std::shared_ptr<ServerLoopState>& state,
    const std::shared_ptr<RouteContext>& routeCtx,
    ResT* res,
    ReqT* req
)
{
    if (routeCtx && routeCtx->kind == RouteHandlerKind::StaticResponse)
    {
        res->onAborted([]() {});
        replayStaticResponse(res, *routeCtx);
        return;
    }

    RequestRouteData route = extractRequestRouteData(req);
    RequestHeaders headers = extractRequestHeaders(req);

    MatchedParams params;
    if (routeCtx)
    {
        params.reserve(routeCtx->paramNames.size());
        for (const std::string& name : routeCtx->paramNames)
        {
            std::string_view value = req->getParameter(name);
            params.emplace_back(name, std::string(value.data(), value.size()));
        }
    }

    res->onAborted([]() {});

    std::unique_ptr<std::string> bodyBuffer;
    res->onData(
        [state, routeCtx, res, route = std::move(route), headers = std::move(headers), params = std::move(params),
         bodyBuffer = std::move(bodyBuffer)](std::string_view data, bool last) mutable
        {
            if (last)
            {
                const MatchedParams* paramsPtr = params.empty() ? nullptr : &params;
                if (bodyBuffer.get())
                {
                    bodyBuffer->append(data);
                    processRequest(state, routeCtx, res, headers, route, *bodyBuffer, paramsPtr);
                }
                else
                {
                    processRequest(state, routeCtx, res, headers, route, data, paramsPtr);
                }
            }
            else
            {
                if (bodyBuffer.get())
                    bodyBuffer->append(data);
                else
                    bodyBuffer = std::make_unique<std::string>(data);
            }
        }
    );
}

template<typename AppT>
static void registerRouteWithApp(AppT* app, const std::shared_ptr<ServerLoopState>& state, const std::shared_ptr<RouteContext>& ctx)
{
    auto handler = [state, ctx](auto* res, auto* req)
    {
        onRouteRequest(state, ctx, res, req);
    };

    const std::string& m = ctx->method;
    const std::string& p = ctx->pattern;
    if (m == "GET")
        app->get(p, std::move(handler));
    else if (m == "POST")
        app->post(p, std::move(handler));
    else if (m == "PUT")
        app->put(p, std::move(handler));
    else if (m == "DELETE")
        app->del(p, std::move(handler));
    else if (m == "PATCH")
        app->patch(p, std::move(handler));
    else if (m == "HEAD")
        app->head(p, std::move(handler));
    else if (m == "OPTIONS")
        app->options(p, std::move(handler));
    else if (m == "CONNECT")
        app->connect(p, std::move(handler));
    else if (m == "TRACE")
        app->trace(p, std::move(handler));
    else
        app->any(p, std::move(handler));
}

template<typename AppT>
static void installHttpRoutes(AppT* app, const std::shared_ptr<ServerLoopState>& state)
{
    app->any(
        "/*",
        [state](auto* res, auto* req)
        {
            onRouteRequest(state, std::shared_ptr<RouteContext>(), res, req);
        }
    );

    for (const auto& ctx : state->routes)
        registerRouteWithApp(app, state, ctx);
}

template<bool SSL, typename AppT>
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
    int routesIndex = 0;

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

        lua_getfield(L, 1, "routes");
        if (lua_istable(L, -1))
        {
            routesIndex = lua_gettop(L);
        }
        else
        {
            lua_pop(L, 1);
        }

        if (handlerIndex == 0 && websocketIndex == 0 && routesIndex == 0)
        {
            luaL_errorL(L, "config table requires a handler function, routes table, websocket config, or any combination");
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

    if (routesIndex != 0)
    {
        parseRoutesTable(L, routesIndex, *state);
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

LUTE_API int luteopen_net_server(lua_State* L)
{
    return NetServer::pushLibrary(L);
}
