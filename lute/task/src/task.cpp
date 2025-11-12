#include "lute/task.h"

#include "lute/ref.h"
#include "lute/runtime.h"
#include "lute/time.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include <cassert>
#include <functional>
#include <iterator>


// taken from extern/luau/VM/lcorolib.cpp
static const char* const statnames[] = {"running", "suspended", "normal", "dead", "dead"};

struct WaitData
{
    uv_timer_t uvTimer;

    ResumeToken resumptionToken;

    uint64_t startedAtMs;

    bool putDeltaTimeOnStack;
    int nargs;
};

static void yieldLuaStateFor(lua_State* L, uint64_t milliseconds, bool putDeltaTimeOnStack, int nargs)
{
    WaitData* yield = new WaitData();
    uv_timer_init(uv_default_loop(), &yield->uvTimer);

    yield->resumptionToken = getResumeToken(L);
    yield->startedAtMs = uv_now(uv_default_loop());
    yield->uvTimer.data = yield;
    yield->putDeltaTimeOnStack = putDeltaTimeOnStack;
    yield->nargs = nargs;

    uv_timer_start(
        &yield->uvTimer,
        [](uv_timer_t* timer)
        {
            WaitData* yield = static_cast<WaitData*>(timer->data);

            yield->resumptionToken->complete(
                [yield](lua_State* L)
                {
                    int stackReturnAmount = yield->putDeltaTimeOnStack ? yield->nargs + 1 : yield->nargs;

                    if (yield->putDeltaTimeOnStack)
                        lua_pushnumber(L, static_cast<double>(uv_now(uv_default_loop()) - yield->startedAtMs) / 1000.0);

                    delete yield;
                    return stackReturnAmount;
                }
            );

            uv_timer_stop(&yield->uvTimer);
        },
        milliseconds,
        0
    );
}

namespace task
{
int lua_defer(lua_State* L)
{
    Runtime* runtime = getRuntime(L);

    runtime->runningThreads.push_back({true, getRefForThread(L), 0});
    return lua_yield(L, 0);
};


int lua_delay(lua_State* L)
{
    int type = lua_type(L, 1);
    uint64_t milliseconds = 0;

    // Handle overloads
    switch (type)
    {
    case LUA_TNUMBER:
        milliseconds = static_cast<uint64_t>(lua_tonumber(L, 1) * 1000);
        break;

    case LUA_TUSERDATA:
    {
        double seconds = getSecondsFromTimespec(getTimespecFromDuration(L, 1));
        milliseconds = static_cast<uint64_t>(seconds * 1000);
        break;
    }

    default:
        luaL_errorL(L, "invalid type %s passed into task.delay", lua_typename(L, lua_type(L, 1)));
        break;
    };

    // remove the wait time
    lua_remove(L, 1);

    lua_State* passedLuaState;

    if (lua_isfunction(L, 1))
    {
        lua_State* NL = lua_newthread(L);
        lua_pop(L, 1);

        passedLuaState = NL;

        // get the function
        lua_xpush(L, NL, 1);

        // remove the function
        lua_remove(L, 1);
    }
    else if (lua_isthread(L, 1))
    {
        passedLuaState = lua_tothread(L, 1);
        lua_remove(L, 1);
    }
    else
    {
        luaL_error(L, "can only pass threads or functions to task.spawn");
    };

    int nargs = lua_gettop(L);
    lua_xmove(L, passedLuaState, nargs);

    yieldLuaStateFor(passedLuaState, milliseconds, false, nargs);

    return 1;
}

int lua_spawn(lua_State* L)
{
    if (lua_isfunction(L, 1))
    {
        lua_State* NL = lua_newthread(L);

        // transfer arguments from other lua_State to the called lua_State
        lua_xpush(L, NL, 1);

        // remove the function arg
        lua_remove(L, 1);

        // insert the thread
        lua_insert(L, 1);
    }
    else if (!lua_isthread(L, 1))
    {
        luaL_error(L, "can only pass threads or functions to task.spawn");
    }

    lute_resume(L);

    // return the thread
    return 1;
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

    yieldLuaStateFor(L, milliseconds, true, 0);

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
