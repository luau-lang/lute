#include "lute/task.h"

#include "lute/common.h"
#include "lute/ref.h"
#include "lute/runtime.h"
#include "lute/time.h"

#include "Luau/Common.h"

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

    bool closed = false;
    bool putDeltaTimeOnStack;
    int nargs;

    void close()
    {
        if (!closed)
        {
            uv_timer_stop(&uvTimer);
            closed = true;
        }
    }

    ~WaitData()
    {
        close();
    }
};

static void yieldLuaStateFor(lua_State* L, uint64_t milliseconds, bool putDeltaTimeOnStack, int nargs)
{
    WaitData* yield = new WaitData();
    uv_timer_init(getRuntimeLoop(L), &yield->uvTimer);

    yield->resumptionToken = getResumeToken(L);
    yield->startedAtMs = uv_now(getRuntimeLoop(L));
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
                        lua_pushnumber(L, static_cast<double>(uv_now(getRuntimeLoop(L)) - yield->startedAtMs) / 1000.0);

                    uv_close(
                        reinterpret_cast<uv_handle_t*>(&yield->uvTimer),
                        [](uv_handle_t* handle)
                        {
                            WaitData* yield = static_cast<WaitData*>(handle->data);
                            delete yield;
                        }
                    );
                    return stackReturnAmount;
                }
            );
        },
        milliseconds,
        0
    );
}

namespace task
{

struct LuaThread
{
    LuaThread(lua_State* L)
        : parent(L)
        , runtime(getRuntime(parent))
    {
        // At this point, the lua stack should look like:
        // [function, args...]
        // or
        // [thread, args...]

        // If passed a thread, we push the 0 or more arguments onto that threads stack and resume it.
        // If passed a function, we push the function and the 0 or more arguments onto a newly created thread's stack
        int toPush = lua_gettop(parent);
        // We only want to resume with the actual number of arguments here, regardless of if the first argument is a thread or a function
        int numResumeArgs = toPush > 1 ? toPush - 1 : 0;
        if (!lua_checkstack(parent, 1))
            luaL_error(L, "Not enough stack space to create a new thread");
        if (lua_isfunction(parent, 1))
        {
            child = lua_newthread(parent);
        }
        else if (lua_isthread(parent, 1))
        {
            child = lua_tothread(parent, 1);
            lua_pushvalue(parent, 1);
            lua_remove(parent, 1);
            toPush--;
        }
        else
        {
            luaL_error(parent, "Expected a thread or function as the first argument.");
        }
        this->resumeArgs = numResumeArgs;

        // At this point the invariant here is that the caller stack should look like:
        // If the first argument was a function
        // [function, 0 or more args to resume, thread to return ]
        // If the first argument was a thread
        // [ 0 or more args to resume the thread with, thread to return ]
        if (!lua_checkstack(child, toPush))
            luaL_error(L, "Not enough stack space to push arguments to child thread");
        for (int i = 1; i <= toPush; i++)
            lua_xpush(parent, child, i);

        // The top of the stack must be the thread that we will return
        LUTE_ASSERT(lua_isthread(parent, -1));
    }

    int defer()
    {
        runtime->runningThreads.push_back({true, getRefForThread(child), resumeArgs});
        return 1;
    }

    int resume()
    {
        auto st = getChildThreadStatus();
        bool suspended = st.first == LUA_COSUS;
        if (!suspended)
        {
            luaL_error(parent, "cannot resume thread with status %s", st.second);
            return 1;
        }

        int resumeStatus = lua_resume(child, parent, resumeArgs);
        bool ok = resumeStatus == LUA_OK || resumeStatus == LUA_YIELD || resumeStatus == LUA_BREAK;

        if (!ok)
        {
            runtime->reportError(child);
	    return 1;
        }

        return 1;
    }

private:
    std::pair<int, const char*> getChildThreadStatus()
    {
        int st = lua_costatus(parent, child);
        return {st, statnames[st]};
    }

    lua_State* parent = nullptr;
    Runtime* runtime = nullptr;
    lua_State* child = nullptr;
    int resumeArgs = 0;
};

int lua_spawn(lua_State* L)
{
    LuaThread newThread{L};
    return newThread.resume();
}

int lua_deferSelf(lua_State* L)
{
    if (lua_gettop(L) != 0)
    {
        luaL_error(L, "task.deferSelf does not take any arguments");
        return 0;
    }
    lua_pushthread(L);
    LuaThread newThread{L};
    newThread.defer();
    return lua_yield(L, 0);
}

int lua_defer(lua_State* L)
{

    LuaThread newThread{L};
    return newThread.defer();
}

int lute_resume(lua_State* L)
{
    if (!lua_isthread(L, 1))
    {
        luaL_error(L, "Expected a thread as the first argument.");
        return 0;
    }
    LuaThread newThread{L};
    return newThread.resume();
}


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
