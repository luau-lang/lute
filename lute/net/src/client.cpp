#include "lute/net.h"

#include "lute/common.h"
#include "lute/runtime.h"
#include "lute/userdatas.h"

#include "system_ca.h"

#include "Luau/DenseHash.h"

#include "lua.h"
#include "lualib.h"

#include "curl/curl.h"

#include <cstring>
#include <memory>
#include <string>
#include <utility>
#include <vector>

namespace net::client
{
struct WebSocketHandle;
int websocket(lua_State* L);
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
    char errorBuffer[CURL_ERROR_SIZE] = {};

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, errorBuffer);

    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writeFunction);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &data);
    applySystemCA(curl);

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
        resp.error = errorBuffer[0] != '\0' ? errorBuffer : curl_easy_strerror(res);
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
