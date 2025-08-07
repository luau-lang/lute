#include "lute/net.h"

#include "lute/runtime.h"

#include "curl/curl.h"
#include "App.h"
#include "Luau/DenseHash.h"
#include "Luau/Variant.h"

#include "lua.h"
#include "lualib.h"

#include <string>
#include <utility>
#include <vector>

namespace net
{

static const std::string kEmptyHeaderKey = "";
struct CurlResponse {
    std::string error;
    std::vector<char> body;
    Luau::DenseHashMap<std::string, std::string> headers;
    long status = 0;

    CurlResponse() : headers(kEmptyHeaderKey) {}
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

    if (method != "GET")
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method.c_str());

    if (!body.empty())
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body.c_str());

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
            body = lua_tostring(L, -1);
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
    std::string hostname;
    int port;
    bool reusePort = false;
};

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

static void parseHeaders(auto* req, lua_State* L)
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
    std::string body = lua_isstring(L, -1) ? lua_tostring(L, -1) : "";
    lua_pop(L, 1);

    res->end(body);
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
    lua_State* L = lua_newthread(state->runtime->GL);
    luaL_sandboxthread(L);
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

    lua_pushvalue(L, -2);
    lua_remove(L, -3);

    int status = lua_resume(L, nullptr, 1);
    if (status != LUA_OK && status != LUA_YIELD)
    {
        std::string error = lua_tostring(L, -1);
        lua_pop(L, 1);

        res->writeStatus("500 Internal Server Error");
        res->end("Server error: " + error);
        return;
    }

    handleResponse(res, L, -1);

    lua_pop(L, 1);
}

void setupAppAndListen(auto* app, std::shared_ptr<ServerLoopState> state, bool& success)
{
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
    std::string hostname = "0.0.0.0";
    int port = 3000;
    bool reusePort = false;
    std::optional<uWS::SocketContextOptions> tlsOptions;
    int handlerIndex = 1;

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

    uWSApp app;
    bool success = false;

    if (tlsOptions)
    {
        auto ssl_app = std::make_unique<uWS::SSLApp>(*tlsOptions);
        state->app = ssl_app.get();
        setupAppAndListen(ssl_app.get(), state, success);
        app = std::move(ssl_app);
    }
    else
    {
        auto plain_app = std::make_unique<uWS::App>();
        state->app = plain_app.get();
        setupAppAndListen(plain_app.get(), state, success);
        app = std::move(plain_app);
    }

    if (!success)
    {
        luaL_errorL(L, "failed to listen on port %d, is it already in use? consider the reuseport option", port);
        return 0;
    }

    state->loopFunction = [state]()
    {
        if (!state->running)
        {
            return;
        }
        Luau::visit(
            [](auto* appPtr)
            {
                if (appPtr)
                    appPtr->run();
            },
            state->app
        );
        state->runtime->schedule(state->loopFunction);
    };

    serverInstances[serverId] = std::move(app);
    serverStates[serverId] = state;

    runtime->schedule(state->loopFunction);

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

    return 1;
}

} // namespace net

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

    return 1;
}
