#include "lua.h"
#include "lualib.h"

static int hello_world(lua_State* L)
{
    lua_pushstring(L, "Hello from a native extension!");
    return 1;
}

static int hello_add(lua_State* L)
{
    double a = luaL_checknumber(L, 1);
    double b = luaL_checknumber(L, 2);
    lua_pushnumber(L, a + b);
    return 1;
}

extern "C" int luteopen_hello(lua_State* L)
{
    lua_createtable(L, 0, 2);

    lua_pushcfunction(L, hello_world, "hello_world");
    lua_setfield(L, -2, "world");

    lua_pushcfunction(L, hello_add, "hello_add");
    lua_setfield(L, -2, "add");

    lua_setreadonly(L, -1, 1);
    return 1;
}
