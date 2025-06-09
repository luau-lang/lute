#include "doctest.h"

#include "lute/require.h"

#include "Luau/Require.h"

#include "lua.h"
#include "lualib.h"

#include <memory>

class LuaStateFixture
{
public:
    LuaStateFixture()
        : luaState(luaL_newstate(), lua_close)
    {
        luaL_openlibs(luaState.get());
        L = luaState.get();
    }

    lua_State* L;

private:
    std::unique_ptr<lua_State, void (*)(lua_State*)> luaState;
};

TEST_CASE_FIXTURE(LuaStateFixture, "open_require")
{
    lua_getglobal(L, "require");
    CHECK(lua_isnil(L, -1));

    RequireCtx ctx{};
    luaopen_require(L, requireConfigInit, &ctx);

    lua_getglobal(L, "require");
    CHECK(!lua_isnil(L, -1));
}
