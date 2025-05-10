#include "lute/task.h"

#include "lua.h"
#include "lute/ref.h"
#include "lute/runtime.h"

// taken from extern/luau/VM/lcorolib.cpp
static const char* const statnames[] = {"running", "suspended", "normal", "dead", "dead"};

namespace task
{
int lua_defer(lua_State* L)
{
    Runtime* runtime = getRuntime(L);

    runtime->runningThreads.push_back({true, getRefForThread(L), 0});
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
