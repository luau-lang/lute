#include "lute/time.h"
#include "uv.h"

#include <iterator>
#include <assert.h>

namespace libtime
{
int lua_now(lua_State* L)
{
    uv_timespec64_t timespec;

    int status = uv_clock_gettime(UV_CLOCK_MONOTONIC, &timespec);
    assert(status == 0);

    // both of these are ints, so we cast them to double.
    lua_pushnumber(L, static_cast<double>(timespec.tv_sec) + static_cast<double>(timespec.tv_nsec / 1e9));

    return 1;
}

} // namespace libtime

int luaopen_time(lua_State* L)
{
    luaL_register(L, "time", libtime::lib);

    return 1;
}

int luteopen_time(lua_State* L)
{
    lua_createtable(L, 0, std::size(libtime::lib));

    for (auto& [name, func] : libtime::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    return 1;
}
