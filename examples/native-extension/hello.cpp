#include "lua.h"
#include "lualib.h"

#if defined(_WIN32)
#define LUTE_EXPORT __declspec(dllexport)
#else
#define LUTE_EXPORT
#endif

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

extern "C" LUTE_EXPORT const int lute_module_abi_version = 1;

// Type definitions embedded in the shared library, read by `lute check`.
extern "C" LUTE_EXPORT const char lute_types[] = R"luau(
local hello = {}

function hello.world(): string
    error("stub")
end

function hello.add(a: number, b: number): number
    error("stub")
end

return table.freeze(hello)
)luau";

extern "C" LUTE_EXPORT int luteopen_hello(lua_State* L)
{
    lua_createtable(L, 0, 2);

    lua_pushcfunction(L, hello_world, "hello_world");
    lua_setfield(L, -2, "world");

    lua_pushcfunction(L, hello_add, "hello_add");
    lua_setfield(L, -2, "add");

    lua_setreadonly(L, -1, 1);
    return 1;
}
