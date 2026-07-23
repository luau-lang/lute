#include "lute/common.h"
#include "lute/net.h"
#include "lute/userdatas.h"

#include "lua.h"
#include "lualib.h"

#include "curl/curl.h"

#include <cstring>
#include <memory>

namespace net::client
{
struct WebSocketHandle;
struct TCPStreamHandle;
int request(lua_State* L);
int websocket(lua_State* L);
int connect(lua_State* L);
int ws_send(lua_State* L);
int ws_close(lua_State* L);
int tcp_write(lua_State* L);
int tcp_read(lua_State* L);
int tcp_handshake(lua_State* L);
int tcp_close(lua_State* L);
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

static void initializeWebSocketHandle(lua_State* L) {
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

static void initializeTCPStreamHandle(lua_State* L) {
    luaL_newmetatable(L, "TCPStreamHandle");

    lua_pushcfunction(
        L,
        [](lua_State* L)
        {
            const char* index = luaL_checkstring(L, -1);

            if (strcmp(index, "write") == 0)
            {
                lua_pushcfunction(L, net::client::tcp_write, "TCPStreamHandle.write");
                return 1;
            }

            if (strcmp(index, "read") == 0)
            {
                lua_pushcfunction(L, net::client::tcp_read, "TCPStreamHandle.read");
                return 1;
            }

            if (strcmp(index, "close") == 0)
            {
                lua_pushcfunction(L, net::client::tcp_close, "TCPStreamHandle.close");
                return 1;
            }

            if (strcmp(index, "handshake") == 0)
            {
                lua_pushcfunction(L, net::client::tcp_handshake, "TCPStreamHandle.handshake");
                return 1;
            }

            return 0;
        },
        "TCPStreamHandle.__index"
    );
    lua_setfield(L, -2, "__index");

    lua_pushstring(L, "TCPStreamHandle");
    lua_setfield(L, -2, "__type");

    lua_setuserdatadtor(
        L,
        kTCPStreamHandleTag,
        [](lua_State*, void* ud)
        {
            std::destroy_at(static_cast<std::shared_ptr<net::client::TCPStreamHandle>*>(ud));
        }
    );

    lua_setuserdatametatable(L, kTCPStreamHandleTag);
}


static void initializeNetClient(lua_State* L)
{
    initializeWebSocketHandle(L);
    initializeTCPStreamHandle(L);
}
} // namespace

const char* const NetClient::properties[] = {nullptr};

const luaL_Reg NetClient::lib[] = {
    {"request", net::client::request},
    {"websocket", net::client::websocket},
    {"connect", net::client::connect},
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
