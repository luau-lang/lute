#include "cliruntimefixture.h"

#include "lua.h"
#include "lualib.h"

#include "Luau/Compiler.h"

static int capture(lua_State* L)
{
    const char* str = luaL_tolstring(L, 1, nullptr);
    lua_pushstring(L, "capturedoutput");
    lua_pushstring(L, str ? str : "");
    lua_settable(L, LUA_REGISTRYINDEX);
    return 0;
}

CliRuntimeFixture::CliRuntimeFixture()
    : runtime(std::make_unique<Runtime>())
{
    L = setupCliState(*runtime, [](lua_State* L) {
        lua_pushstring(L, "capturedoutput");
        lua_pushstring(L, "");
        lua_settable(L, LUA_REGISTRYINDEX);
        lua_pushcfunction(L, capture, "capture");
        lua_setglobal(L, "capture");
    });
}

std::string CliRuntimeFixture::getCapturedOutput()
{
    lua_getfield(L, LUA_REGISTRYINDEX, "capturedoutput");
    const char* output = lua_tostring(L, -1);
    lua_pop(L, 1);
    return output ? output : "";
}

bool CliRuntimeFixture::runCode(const std::string& source)
{
    std::string bytecode = Luau::compile(source, Luau::CompileOptions());
    return runBytecode(*runtime, bytecode, "=stdin", L, 0, nullptr);
}