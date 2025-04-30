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
#include <mutex>
#include <unordered_map>

namespace net
{

static size_t writeFunction(void* contents, size_t size, size_t nmemb, void* context)
{
    std::vector<char>& target = *(std::vector<char>*)context;
    size_t fullsize = size * nmemb;

    target.insert(target.end(), (char*)contents, (char*)contents + fullsize);

    return fullsize;
}

static std::pair<std::string, std::vector<char>> requestData(const std::string& url)
{
    CURL* curl = curl_easy_init();

    if (!curl)
        return {"failed to initialize", {}};

    std::vector<char> data;

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writeFunction);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &data);

    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);

    CURLcode res = curl_easy_perform(curl);

    if (res != CURLE_OK)
        return {curl_easy_strerror(res), {}};

    curl_easy_cleanup(curl);
    return {"", data};
}

int get(lua_State* L)
{
    std::string url = luaL_checkstring(L, 1);

    auto [error, data] = requestData(url);

    if (!error.empty())
        luaL_errorL(L, "network request failed: %s", error.c_str());

    lua_pushlstring(L, data.data(), data.size());
    return 1;
}

int getAsync(lua_State* L)
{
    std::string url = luaL_checkstring(L, 1);

    auto token = getResumeToken(L);

    // TODO: add cancellations
    token->runtime->runInWorkQueue(
        [=]
        {
            auto [error, data] = requestData(url);

            if (!error.empty())
            {
                token->fail("network request failed: " + error);
            }
            else
            {
                token->complete(
                    [data = std::move(data)](lua_State* L)
                    {
                        lua_pushlstring(L, data.data(), data.size());
                        return 1;
                    }
                );
            }
        }
    );

    return lua_yield(L, 0);
}

using uWSApp = Luau::Variant<std::unique_ptr<uWS::App>, std::unique_ptr<uWS::SSLApp>>;

static const int kEmptyServerKey = 0;
static Luau::DenseHashMap<int, uWSApp> serverInstances(kEmptyServerKey);
static Luau::DenseHashMap<int, std::shared_ptr<struct ServerLoopState>> serverStates(kEmptyServerKey);
static int nextServerId = 1;

// Track used ports for proper error detection
static std::mutex portMutex;
static std::unordered_map<std::string, bool> usedPorts;

struct ServerLoopState
{
    Luau::Variant<uWS::App*, uWS::SSLApp*> app;
    Runtime* runtime;
    bool running = true;
    std::function<void()> loopFunction;
    std::shared_ptr<Ref> handlerRef;
    std::string hostname;
    int port;
    bool allowPortReuse = false;
};

static void parseQuery(const std::string& query, lua_State* L)
{
    lua_createtable(L, 0, 0);
    size_t start = 0;
    size_t end = query.find('&');
    while (end != std::string::npos)
    {
        std::string pair = query.substr(start, end - start);
        size_t eq = pair.find('=');
        if (eq != std::string::npos)
        {
            std::string key = pair.substr(0, eq);
            std::string value = pair.substr(eq + 1);
            lua_pushstring(L, key.c_str());
            lua_pushstring(L, value.c_str());
            lua_settable(L, -3);
        }
        start = end + 1;
        end = query.find('&', start);
    }
    std::string pair = query.substr(start);
    size_t eq = pair.find('=');
    if (eq != std::string::npos)
    {
        std::string key = pair.substr(0, eq);
        std::string value = pair.substr(eq + 1);
        lua_pushstring(L, key.c_str());
        lua_pushstring(L, value.c_str());
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
        while (lua_next(L, -2) != 0)
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
    const std::string& path,
    const std::string& query,
    const std::string_view& body
)
{
    lua_State* L = state->runtime->GL;

    lua_createtable(L, 0, 5);

    lua_pushstring(L, "method");
    lua_pushstring(L, method.c_str());
    lua_settable(L, -3);

    lua_pushstring(L, "path");
    lua_pushstring(L, path.c_str());
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

    if (lua_pcall(L, 1, 1, 0) != 0)
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

void setupAppAndListen(auto* app, std::shared_ptr<ServerLoopState> state, bool& success, std::string& errorMessage)
{
    app->any(
        "/*",
        [state](auto* res, auto* req)
        {
            std::string method = std::string(req->getMethod());
            std::transform(method.begin(), method.end(), method.begin(), ::toupper);
            std::string url = std::string(req->getUrl());
            std::string path = url;

            // Split URL into path and query
            size_t queryPos = url.find('?');
            std::string query;
            if (queryPos != std::string::npos)
            {
                path = url.substr(0, queryPos);
                query = url.substr(queryPos + 1);
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

    app->listen(
        state->hostname,
        state->port,
        [&success, &errorMessage, state](auto* listen_socket)
        {
            if (listen_socket)
            {
                success = true;
            }
            else
            {
                success = false;
                // Use more specific error message for binding failures
                errorMessage = "Failed to bind server to " + state->hostname + ":" + std::to_string(state->port) +
                               ", the port may be in use by another application";
            }
        }
    );
}

// Function to check if port is already in use
static bool isPortInUse(const std::string& hostname, int port)
{
    std::string key = hostname + ":" + std::to_string(port);
    std::lock_guard<std::mutex> guard(portMutex);
    return usedPorts.find(key) != usedPorts.end();
}

// Function to mark a port as used
static void markPortAsUsed(const std::string& hostname, int port)
{
    std::string key = hostname + ":" + std::to_string(port);
    std::lock_guard<std::mutex> guard(portMutex);
    usedPorts[key] = true;
}

// Function to release a port
static void releasePort(const std::string& hostname, int port)
{
    std::string key = hostname + ":" + std::to_string(port);
    std::lock_guard<std::mutex> guard(portMutex);
    usedPorts.erase(key);
}

// Enhanced hostname validation
static bool isValidHostname(const std::string& hostname)
{
    // Allow common localhost values
    if (hostname == "0.0.0.0" || hostname == "localhost" || hostname == "127.0.0.1" || hostname == "::1")
        return true;

    // If hostname is empty, it's invalid
    if (hostname.empty())
        return false;

    // Basic validation for domain names
    if (hostname.length() > 255)
        return false;

    // Check for invalid characters
    if (hostname.find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-") != std::string::npos)
        return false;

    // Can't start or end with hyphen
    if (hostname[0] == '-' || hostname[hostname.length() - 1] == '-')
        return false;

    // Can't have consecutive dots
    if (hostname.find("..") != std::string::npos)
        return false;

    return true;
}

bool closeServer(int serverId)
{
    if (!serverInstances.contains(serverId) || !serverStates.contains(serverId))
    {
        return false;
    }

    auto state = serverStates[serverId];

    // Release the port when server closes
    releasePort(state->hostname, state->port);

    Luau::visit(
        [](auto* appPtr)
        {
            if (appPtr)
                appPtr->close();
        },
        state->app
    );
    state->running = false;

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

// Implementation that matches the name in the header file
int lua_serve(lua_State* L)
{
    std::string hostname = "0.0.0.0";
    int port = 3000;
    std::optional<uWS::SocketContextOptions> tlsOptions;
    int handlerIndex = 1;
    bool allowPortReuse = false;

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

        lua_getfield(L, 1, "allow_port_reuse");
        if (lua_isboolean(L, -1))
        {
            allowPortReuse = lua_toboolean(L, -1);
        }
        lua_pop(L, 1);

        lua_getfield(L, 1, "tls");
        if (lua_istable(L, -1))
        {
            tlsOptions.emplace();

            lua_getfield(L, -1, "cert_file_name");
            if (!lua_isstring(L, -1))
            {
                luaL_errorL(L, "tls config requires 'cert_file_name' (string)");
                return 0;
            }
            tlsOptions->cert_file_name = lua_tostring(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, -1, "key_file_name");
            if (!lua_isstring(L, -1))
            {
                luaL_errorL(L, "tls config requires 'key_file_name' (string)");
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

            lua_getfield(L, -1, "ca_file_name");
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

    // Pre-validate the hostname with more detailed error message
    if (!isValidHostname(hostname))
    {
        std::string errorMsg = "Invalid hostname: '" + hostname + "'. Hostnames must contain only letters, numbers, periods, and hyphens.";
        lua_pushnil(L);
        lua_pushstring(L, errorMsg.c_str());
        return 2;
    }

    // Check for port conflicts before attempting to bind
    if (isPortInUse(hostname, port) && !allowPortReuse)
    {
        std::string errorMsg =
            "Port already in use: " + hostname + ":" + std::to_string(port) + ". Try a different port or set allow_port_reuse to true.";
        lua_pushnil(L);
        lua_pushstring(L, errorMsg.c_str());
        return 2;
    }

    Runtime* runtime = getRuntime(L);

    int serverId = nextServerId++;

    auto state = std::make_shared<ServerLoopState>();
    state->runtime = runtime;
    state->hostname = hostname;
    state->port = port;
    state->allowPortReuse = allowPortReuse;

    lua_pushvalue(L, handlerIndex);
    state->handlerRef = std::make_shared<Ref>(L, -1);
    lua_pop(L, 1);

    // Mark the port as used
    markPortAsUsed(hostname, port);

    bool success = false;
    std::string errorMessage;

    // Create the app (we'll remove direct socket option handling for now since it's not compatible)
    if (tlsOptions)
    {
        auto ssl_app = std::make_unique<uWS::SSLApp>(*tlsOptions);
        state->app = ssl_app.get();
        setupAppAndListen(ssl_app.get(), state, success, errorMessage);
        serverInstances[serverId] = std::move(ssl_app);
    }
    else
    {
        auto plain_app = std::make_unique<uWS::App>();
        state->app = plain_app.get();
        setupAppAndListen(plain_app.get(), state, success, errorMessage);
        serverInstances[serverId] = std::move(plain_app);
    }

    if (!success)
    {
        // Release the port since binding failed
        releasePort(hostname, port);

        // Return nil and error message to Lua
        lua_pushnil(L);
        lua_pushstring(L, errorMessage.c_str());
        return 2;
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