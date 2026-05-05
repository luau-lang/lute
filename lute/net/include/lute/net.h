#pragma once

#include "lute/library.h"

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library
LUTE_API int luaopen_net(lua_State* L);
// open the library as a table on top of the stack
LUTE_API int luteopen_net(lua_State* L);

LUTE_API int luteopen_net_client(lua_State* L);
LUTE_API int luteopen_net_server(lua_State* L);

struct NetClient : LuteLibrary<NetClient>
{
    static constexpr const char kName[] = "net.client";
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
    static const char* const properties[];
};

struct NetServer : LuteLibrary<NetServer>
{
    static constexpr const char kName[] = "net.server";
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
    static const char* const properties[];
};

struct Net : LuteLibrary<Net>
{
    static constexpr const char kName[] = "net";
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
    static const char* const properties[];
};
