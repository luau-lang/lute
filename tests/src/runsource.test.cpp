#include "lute/options.h"
#include "lute/requiresetup.h"
#include "lute/runtime.h"

#include "lua.h"
#include "lualib.h"

#include <string>
#include <vector>

#include "doctest.h"

static std::vector<std::string> capturedOutputs;

static int capture(lua_State* L)
{
    const char* str = luaL_tolstring(L, 1, nullptr);
    capturedOutputs.emplace_back(str);
    return 0;
}

TEST_CASE("Runtime_runSource_executes_source")
{
    capturedOutputs.clear();

    Runtime runtime;
    setupRunState(
        runtime,
        [](lua_State* L)
        {
            lua_pushcfunction(L, capture, "");
            lua_setglobal(L, "report");
        }
    );

    bool result = runtime.runSource(
        R"(
        report("hello from runSource")
    )",
        copts()
    );

    CHECK(result == true);
    REQUIRE(capturedOutputs.size() == 1);
    CHECK(capturedOutputs[0] == "hello from runSource");
}

TEST_CASE("Runtime_runSource_multiple_outputs")
{
    capturedOutputs.clear();

    Runtime runtime;
    setupRunState(
        runtime,
        [](lua_State* L)
        {
            lua_pushcfunction(L, capture, "");
            lua_setglobal(L, "report");
        }
    );

    bool result = runtime.runSource(
        R"(
        report("first")
        report("second")
        report("third")
    )",
        copts()
    );

    CHECK(result == true);
    REQUIRE(capturedOutputs.size() == 3);
    CHECK(capturedOutputs[0] == "first");
    CHECK(capturedOutputs[1] == "second");
    CHECK(capturedOutputs[2] == "third");
}

TEST_CASE("Runtime_runSource_computation")
{
    capturedOutputs.clear();

    Runtime runtime;
    setupRunState(
        runtime,
        [](lua_State* L)
        {
            lua_pushcfunction(L, capture, "");
            lua_setglobal(L, "report");
        }
    );

    bool result = runtime.runSource(
        R"(
        local sum = 0
        for i = 1, 10 do
            sum += i
        end
        report(tostring(sum))
    )",
        copts()
    );

    CHECK(result == true);
    REQUIRE(capturedOutputs.size() == 1);
    CHECK(capturedOutputs[0] == "55");
}

TEST_CASE("Runtime_runSource_error")
{
    Runtime runtime;
    setupRunState(runtime);

    bool result = runtime.runSource(
        R"(
        error("fail")
    )",
        copts()
    );

    CHECK(result == false);
}
