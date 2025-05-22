#include "lute/task.h"

#include "lua.h"
#include "lualib.h"
#include "lute/ref.h"
#include "lute/runtime.h"
#include "uv.h"
#include "lute/runtime.h"
#include "lute/time.h"
#include <cassert>
#include <functional>

// taken from extern/luau/VM/lcorolib.cpp
static const char* const statnames[] = {"running", "suspended", "normal", "dead", "dead"};

struct WaitData
{
    uv_timer_t uvTimer;

    ResumeToken resumptionToken;

    uint64_t startedAtMs;
};

namespace task
{
int lua_defer(lua_State* L)
{
    Runtime* runtime = getRuntime(L);

    runtime->runningThreads.push_back({true, getRefForThread(L), 0});
    return lua_yield(L, 0);
}

int lua_wait(lua_State* L)
{
    int type = lua_type(L, 1);
    uint64_t milliseconds = 0;

    // Handle overloads
    switch (type)
    {
        // TNONE and TNIL fall into the same default case of 0
        // Supports nil & none
    case LUA_TNONE:
    case LUA_TNIL:
        milliseconds = 0;
        break;
    case LUA_TNUMBER:
        milliseconds = static_cast<uint64_t>(lua_tonumber(L, 1) * 1000);
        break;
    case LUA_TUSERDATA:
        double seconds = getSecondsFromTimespec(getTimespecFromDuration(L, 1));
        milliseconds = static_cast<uint64_t>(seconds * 1000);

        break;
    };

    WaitData* yield = new WaitData();
    uv_timer_init(uv_default_loop(), &yield->uvTimer);

    yield->resumptionToken = getResumeToken(L);
    yield->startedAtMs = uv_now(uv_default_loop());
    yield->uvTimer.data = yield;

    uv_timer_start(
        &yield->uvTimer,
        [](uv_timer_t* timer)
        {
            WaitData* yield = static_cast<WaitData*>(timer->data);

            yield->resumptionToken->complete(
                [yield](lua_State* L)
                {
                    lua_pushnumber(L, static_cast<double>(uv_now(uv_default_loop()) - yield->startedAtMs) / 1000.0);

                    delete yield;
                    return 1;
                }
            );

            uv_timer_stop(&yield->uvTimer);
        },
        milliseconds,
        0
    );

    return lua_yield(L, 0);
}

int lute_resume(lua_State* L)
{
    Runtime* runtime = getRuntime(L);

    lua_State* thread = lua_tothread(L, 1);
    luaL_argexpected(L, thread, 1, "thread");

    int currentThreadStatus = lua_costatus(L, thread);
    if (currentThreadStatus != LUA_COSUS)
    {
        luaL_errorL(L, "cannot resume %s coroutine", statnames[currentThreadStatus]);

        return 1;
    };

    lua_remove(L, 1);

    int args = lua_gettop(L);
    lua_xmove(L, thread, args);

    int resumptionStatus = lua_resume(thread, L, args);
    if (resumptionStatus != LUA_OK && resumptionStatus != LUA_YIELD && resumptionStatus != LUA_BREAK)
    {
        runtime->reportError(thread);
    }

    return 0;
}

} // namespace task

int luaopen_task(lua_State* L)
{
    luaL_register(L, "task", task::lib);

    return 1;
}

int luteopen_task(lua_State* L)
{
    lua_createtable(L, 0, std::size(task::lib));

    for (auto& [name, func] : task::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    return 1;
}
