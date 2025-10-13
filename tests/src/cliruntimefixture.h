#pragma once
#include "doctest.h"

#include "lute/climain.h"
#include "lute/runtime.h"

#include "lua.h"

#include "Luau/Compiler.h"

#include <memory>

static int capture(lua_State* L)
{
    const char* str = lua_tostring(L, 1);
    lua_pushstring(L, "capturedoutput");
    lua_pushstring(L, str ? str : "");
    lua_settable(L, LUA_REGISTRYINDEX);
    return 0;
}

class CliRuntimeFixture
{
public:
    CliRuntimeFixture()
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

    std::string getCapturedOutput()
    {
        lua_getfield(L, LUA_REGISTRYINDEX, "capturedoutput");
        const char* output = lua_tostring(L, -1);
        lua_pop(L, 1);
        return output ? output : "";
    }

    bool runCode(const std::string& source)
    {
        std::string bytecode = Luau::compile(source, Luau::CompileOptions());
        return runBytecode(*runtime, bytecode, "=stdin", L);
    }

    lua_State* L;

private:
    std::unique_ptr<Runtime> runtime;
};