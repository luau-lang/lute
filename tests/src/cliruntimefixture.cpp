#include "cliruntimefixture.h"

#include "lute/climain.h"
#include "lute/requiresetup.h"

#include "Luau/Compiler.h"

#include "lua.h"
#include "lualib.h"

static int report(lua_State* L)
{
    const char* str = luaL_tolstring(L, 1, nullptr);
    lua_getfield(L, LUA_REGISTRYINDEX, "reporter");
    TestReporter* reporter = static_cast<TestReporter*>(lua_touserdata(L, -1));
    reporter->reportOutput(str);
    return 0;
}

CliRuntimeFixture::CliRuntimeFixture()
    : runtime(std::make_unique<Runtime>())
{
    L = setupCliState(
        *runtime,
        [rep = reporter.get()](lua_State* L)
        {
            lua_pushlightuserdata(L, (void*)rep);
            lua_setfield(L, LUA_REGISTRYINDEX, "reporter");
            lua_pushcfunction(L, report, "");
            lua_setglobal(L, "report");
        }
    );
}

bool CliRuntimeFixture::runCode(const std::string& source)
{
    std::string bytecode = Luau::compile(source, Luau::CompileOptions());
    return runBytecode(*runtime, bytecode, "=stdin", L, 0, nullptr, getReporter());
}
