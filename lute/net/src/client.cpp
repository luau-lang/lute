#include "lute/common.h"
#include "lute/net.h"
#include "lute/runtime.h"
#include "lute/userdatas.h"

#include "Luau/DenseHash.h"

#include "lua.h"
#include "lualib.h"

#include "curl/curl.h"

#include <cctype>
#include <cstring>
#include <limits>
#include <memory>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "system_ca.h"

namespace net::client
{
struct WebSocketHandle;
int websocket(lua_State* L);
int ws_send(lua_State* L);
int ws_close(lua_State* L);
} // namespace net::client

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
static constexpr long kDefaultRequestTimeoutMs = 5 * 60 * 1000;
static constexpr long kDefaultConnectTimeoutMs = 30 * 1000;

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

struct CurlMultiManager;

struct HttpRequestState
{
    CURL* easy = nullptr;
    curl_slist* headerList = nullptr;
    std::string url;
    std::string method;
    std::string body;
    CurlResponse response;
    char errorBuffer[CURL_ERROR_SIZE] = {};
    ResumeToken token;
    CurlMultiManager* manager = nullptr;

    ~HttpRequestState()
    {
        if (headerList)
            curl_slist_free_all(headerList);

        if (easy)
            curl_easy_cleanup(easy);
    }
};

struct CurlSocketState
{
    curl_socket_t socket = CURL_SOCKET_BAD;
    uv_poll_t poll{};
    CurlMultiManager* manager = nullptr;
    int activeEvents = 0;
    bool closing = false;
};

static size_t writeFunction(char* ptr, size_t size, size_t nmemb, void* userdata)
{
    auto* state = static_cast<HttpRequestState*>(userdata);
    LUTE_ASSERT(state);

    std::vector<char>* target = &state->response.body;
    LUTE_ASSERT(target);

    size_t fullsize = size * nmemb;
    target->insert(target->end(), ptr, ptr + fullsize);
    return fullsize;
}

static void collectResponseHeaders(HttpRequestState& state)
{
    curl_header* prev = nullptr;
    curl_header* h;

    while ((h = curl_easy_nextheader(state.easy, CURLH_HEADER, -1, prev)))
    {
        std::string name = h->name;
        std::string value = h->value;

        if (state.response.headers.contains(name))
        {
            state.response.headers[name] += ", " + value;
        }
        else
        {
            state.response.headers[name] = value;
        }
        prev = h;
    }
}

static int pushResponse(lua_State* L, CurlResponse resp)
{
    lua_createtable(L, 0, 4);

    lua_pushstring(L, "body");
    lua_pushlstring(L, resp.body.empty() ? "" : resp.body.data(), resp.body.size());
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

struct CurlMultiManager
{
    explicit CurlMultiManager(Runtime* runtime)
        : runtime(runtime)
    {
        multi = curl_multi_init();
        if (!multi)
        {
            initError = "failed to initialize curl multi handle";
            return;
        }

        int timerResult = uv_timer_init(runtime->getEventLoop(), &timer);
        if (timerResult != 0)
        {
            initError = std::string("failed to initialize curl timer: ") + uv_strerror(timerResult);
            return;
        }

        timerInitialized = true;
        timer.data = this;

        curl_multi_setopt(multi, CURLMOPT_SOCKETFUNCTION, &CurlMultiManager::socketCallback);
        curl_multi_setopt(multi, CURLMOPT_SOCKETDATA, this);
        curl_multi_setopt(multi, CURLMOPT_TIMERFUNCTION, &CurlMultiManager::timerCallback);
        curl_multi_setopt(multi, CURLMOPT_TIMERDATA, this);
    }

    Runtime* runtime = nullptr;
    CURLM* multi = nullptr;
    uv_timer_t timer{};
    bool timerInitialized = false;
    bool timerClosing = false;
    bool closing = false;
    bool deleteWhenClosed = false;
    int pendingCloseHandles = 0;
    int runningHandles = 0;
    std::string initError;
    std::unordered_map<curl_socket_t, CurlSocketState*> sockets;
    std::unordered_map<CURL*, std::unique_ptr<HttpRequestState>> requests;

    bool ok() const
    {
        return initError.empty();
    }

    bool addRequest(std::unique_ptr<HttpRequestState> state, std::string& error)
    {
        if (closing || !multi)
        {
            error = "curl multi manager is closing";
            return false;
        }

        CURL* easy = state->easy;
        state->manager = this;
        requests[easy] = std::move(state);

        CURLMcode result = curl_multi_add_handle(multi, easy);
        if (result != CURLM_OK)
        {
            auto it = requests.find(easy);
            if (it != requests.end())
                requests.erase(it);

            error = curl_multi_strerror(result);
            return false;
        }

        return true;
    }

    void socketAction(curl_socket_t socket, int action)
    {
        if (closing || !multi)
            return;

        CURLMcode result = curl_multi_socket_action(multi, socket, action, &runningHandles);
        if (result != CURLM_OK)
        {
            failAll(std::string("curl multi socket action failed: ") + curl_multi_strerror(result));
            return;
        }

        drainCompletions();
    }

    void drainCompletions()
    {
        if (closing || !multi)
            return;

        int messagesLeft = 0;
        CURLMsg* message = nullptr;
        while ((message = curl_multi_info_read(multi, &messagesLeft)))
        {
            if (message->msg != CURLMSG_DONE)
                continue;

            completeRequest(message->easy_handle, message->data.result);
        }
    }

    void completeRequest(CURL* easy, CURLcode result)
    {
        auto it = requests.find(easy);
        if (it == requests.end())
            return;

        curl_multi_remove_handle(multi, easy);

        std::unique_ptr<HttpRequestState> state = std::move(it->second);
        requests.erase(it);

        if (result != CURLE_OK)
        {
            std::string error = state->errorBuffer[0] != '\0' ? state->errorBuffer : curl_easy_strerror(result);
            state->token->fail("network request failed: " + error);
        }
        else
        {
            curl_easy_getinfo(easy, CURLINFO_RESPONSE_CODE, &state->response.status);
            collectResponseHeaders(*state);

            state->token->complete(
                [resp = std::move(state->response)](lua_State* L) mutable
                {
                    return pushResponse(L, std::move(resp));
                }
            );
        }

        maybeDestroyWhenIdle();
    }

    CurlSocketState* createSocketState(curl_socket_t socket)
    {
        auto* state = new CurlSocketState();
        state->socket = socket;
        state->manager = this;
        state->poll.data = state;

        int result = uv_poll_init_socket(runtime->getEventLoop(), &state->poll, socket);
        if (result != 0)
        {
            delete state;
            return nullptr;
        }

        sockets[socket] = state;
        curl_multi_assign(multi, socket, state);
        return state;
    }

    bool updateSocket(CurlSocketState* state, int events)
    {
        if (!state || state->closing)
            return false;

        if (state->activeEvents == events)
            return true;

        if (events == 0)
        {
            uv_poll_stop(&state->poll);
            state->activeEvents = 0;
            return true;
        }

        int result = uv_poll_start(
            &state->poll,
            events,
            [](uv_poll_t* handle, int status, int events)
            {
                auto* state = static_cast<CurlSocketState*>(handle->data);
                if (!state || state->closing || !state->manager)
                    return;

                int action = 0;
                if (status < 0)
                    action = CURL_CSELECT_ERR;
                else
                {
                    if (events & UV_READABLE)
                        action |= CURL_CSELECT_IN;
                    if (events & UV_WRITABLE)
                        action |= CURL_CSELECT_OUT;
                }

                state->manager->socketAction(state->socket, action);
            }
        );

        if (result != 0)
            return false;

        state->activeEvents = events;
        return true;
    }

    void closeSocket(CurlSocketState* state)
    {
        if (!state || state->closing)
            return;

        state->closing = true;
        sockets.erase(state->socket);

        if (multi)
            curl_multi_assign(multi, state->socket, nullptr);

        uv_poll_stop(&state->poll);
        pendingCloseHandles++;
        uv_close(
            reinterpret_cast<uv_handle_t*>(&state->poll),
            [](uv_handle_t* handle)
            {
                auto* state = static_cast<CurlSocketState*>(handle->data);
                CurlMultiManager* manager = state ? state->manager : nullptr;
                delete state;

                if (manager)
                    manager->onHandleClosed();
            }
        );
    }

    void failAll(std::string error)
    {
        if (multi)
        {
            for (auto& request : requests)
                curl_multi_remove_handle(multi, request.first);
        }

        std::vector<std::unique_ptr<HttpRequestState>> pending;
        pending.reserve(requests.size());
        for (auto& request : requests)
            pending.push_back(std::move(request.second));
        requests.clear();

        for (auto& request : pending)
            request->token->fail(error);

        maybeDestroyWhenIdle();
    }

    void beginClose(bool deleteAfterClose)
    {
        if (closing)
            return;

        closing = true;
        deleteWhenClosed = deleteAfterClose;

        if (!requests.empty())
            failAll("network request cancelled");

        std::vector<CurlSocketState*> socketStates;
        socketStates.reserve(sockets.size());
        for (auto& socket : sockets)
            socketStates.push_back(socket.second);

        for (CurlSocketState* state : socketStates)
            closeSocket(state);

        if (timerInitialized && !timerClosing)
        {
            uv_timer_stop(&timer);
            timerClosing = true;
            pendingCloseHandles++;
            uv_close(
                reinterpret_cast<uv_handle_t*>(&timer),
                [](uv_handle_t* handle)
                {
                    auto* manager = static_cast<CurlMultiManager*>(handle->data);
                    if (manager)
                        manager->onHandleClosed();
                }
            );
        }

        if (multi)
        {
            curl_multi_cleanup(multi);
            multi = nullptr;
        }

        finishCloseIfReady();
    }

    void onHandleClosed()
    {
        pendingCloseHandles--;
        finishCloseIfReady();
    }

    void finishCloseIfReady()
    {
        if (deleteWhenClosed && pendingCloseHandles == 0)
            delete this;
    }

    void maybeDestroyWhenIdle();

    static int socketCallback(CURL*, curl_socket_t socket, int what, void* userp, void* socketp)
    {
        auto* manager = static_cast<CurlMultiManager*>(userp);
        if (!manager || manager->closing)
            return 0;

        auto* state = static_cast<CurlSocketState*>(socketp);

        if (what == CURL_POLL_REMOVE)
        {
            manager->closeSocket(state);
            return 0;
        }

        if (!state)
        {
            state = manager->createSocketState(socket);
            if (!state)
                return -1;
        }

        int events = 0;
        if (what == CURL_POLL_IN || what == CURL_POLL_INOUT)
            events |= UV_READABLE;
        if (what == CURL_POLL_OUT || what == CURL_POLL_INOUT)
            events |= UV_WRITABLE;

        return manager->updateSocket(state, events) ? 0 : -1;
    }

    static int timerCallback(CURLM*, long timeoutMs, void* userp)
    {
        auto* manager = static_cast<CurlMultiManager*>(userp);
        if (!manager || manager->closing || !manager->timerInitialized)
            return 0;

        if (timeoutMs < 0)
        {
            uv_timer_stop(&manager->timer);
            return 0;
        }

        uint64_t delay = timeoutMs == 0 ? 0 : static_cast<uint64_t>(timeoutMs);
        uv_timer_start(
            &manager->timer,
            [](uv_timer_t* handle)
            {
                auto* manager = static_cast<CurlMultiManager*>(handle->data);
                if (manager)
                    manager->socketAction(CURL_SOCKET_TIMEOUT, 0);
            },
            delay,
            0
        );

        return 0;
    }
};

static std::unordered_map<Runtime*, CurlMultiManager*> curlManagers;

void CurlMultiManager::maybeDestroyWhenIdle()
{
    if (!requests.empty())
        return;

    auto it = curlManagers.find(runtime);
    if (it != curlManagers.end() && it->second == this)
        curlManagers.erase(it);

    beginClose(true);
}

static CurlMultiManager* getCurlMultiManager(Runtime* runtime, std::string& error)
{
    auto it = curlManagers.find(runtime);
    if (it != curlManagers.end())
        return it->second;

    auto* manager = new CurlMultiManager(runtime);
    if (!manager->ok())
    {
        error = manager->initError;
        manager->beginClose(true);
        return nullptr;
    }

    curlManagers[runtime] = manager;
    return manager;
}

static bool isValidHeaderNameChar(unsigned char c)
{
    return std::isalnum(c) || c == '!' || c == '#' || c == '$' || c == '%' || c == '&' || c == '\'' || c == '*' || c == '+' || c == '-' || c == '.' ||
           c == '^' || c == '_' || c == '`' || c == '|' || c == '~';
}

static bool isValidHeaderName(const std::string& name)
{
    if (name.empty())
        return false;

    for (unsigned char c : name)
    {
        if (!isValidHeaderNameChar(c))
            return false;
    }

    return true;
}

static bool containsCrLf(const std::string& value)
{
    return value.find('\r') != std::string::npos || value.find('\n') != std::string::npos;
}

static std::unique_ptr<HttpRequestState> createRequestState(
    std::string url,
    std::string method,
    std::string body,
    std::vector<std::pair<std::string, std::string>> headers,
    ResumeToken token,
    std::string& error
)
{
    CURL* curl = curl_easy_init();
    if (!curl)
    {
        error = "failed to initialize curl easy handle";
        return nullptr;
    }

    auto state = std::make_unique<HttpRequestState>();
    state->easy = curl;
    state->url = std::move(url);
    state->method = std::move(method);
    state->body = std::move(body);
    state->token = std::move(token);

    curl_easy_setopt(curl, CURLOPT_URL, state->url.c_str());
    curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, state->errorBuffer);
    curl_easy_setopt(curl, CURLOPT_PRIVATE, state.get());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writeFunction);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, state.get());
    curl_easy_setopt(curl, CURLOPT_TIMEOUT_MS, kDefaultRequestTimeoutMs);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, kDefaultConnectTimeoutMs);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, headers.empty() ? 1L : 0L);
    curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 20L);
    applySystemCA(curl);

    if (state->method == "HEAD")
    {
        curl_easy_setopt(curl, CURLOPT_NOBODY, 1L);
    }

    if (state->method != "GET")
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, state->method.c_str());

    if (!state->body.empty())
    {
        auto maxCurlOff = (std::numeric_limits<curl_off_t>::max)();
        if (state->body.size() > static_cast<size_t>(maxCurlOff))
        {
            error = "request body is too large";
            return nullptr;
        }

        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, state->body.c_str());
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE_LARGE, static_cast<curl_off_t>(state->body.size()));
    }

    for (const auto& headerPair : headers)
    {
        std::string headerString = headerPair.first + ": " + headerPair.second;
        state->headerList = curl_slist_append(state->headerList, headerString.c_str());
        if (!state->headerList)
        {
            error = "failed to append request header";
            return nullptr;
        }
    }

    if (state->headerList)
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, state->headerList);

    return state;
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

    if ((method == "GET" || method == "HEAD") && !body.empty())
        luaL_error(L, "%s requests cannot include a body", method.c_str());

    for (const auto& header : headers)
    {
        if (!isValidHeaderName(header.first) || containsCrLf(header.first))
            luaL_error(L, "invalid request header name");

        if (containsCrLf(header.second))
            luaL_error(L, "invalid request header value");
    }

    auto token = getResumeToken(L);

    std::string error;
    std::unique_ptr<HttpRequestState> state =
        createRequestState(std::move(url), std::move(method), std::move(body), std::move(headers), token, error);

    if (!state)
    {
        token->fail("network request failed: " + error);
        return lua_yield(L, 0);
    }

    CurlMultiManager* manager = getCurlMultiManager(token->runtime, error);
    if (!manager)
    {
        token->fail("network request failed: " + error);
        return lua_yield(L, 0);
    }

    if (!manager->addRequest(std::move(state), error))
    {
        token->fail("network request failed: " + error);
        return lua_yield(L, 0);
    }

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

LUTE_API int luteopen_net_client(lua_State* L)
{
    return NetClient::pushLibrary(L);
}
