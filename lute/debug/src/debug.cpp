#include "lute/debug.h"

#include "lute/common.h"
#include "lute/debuginternals.h"
#include "lute/runtime.h"
#include "lute/userdatas.h"

#include "lua.h"
#include "lualib.h"

#include <cstring>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

static void checkStack(lua_State* L, int n)
{
    if (!lua_checkstack(L, n))
        luaL_error(L, "stack overflow while pushing return value during debugging");
}

namespace debug
{
static Target* getTarget(lua_State* L, int index)
{
    auto* storage = static_cast<std::shared_ptr<Target>*>(lua_touserdatatagged(L, index, kTargetTag));
    if (!storage || !*storage)
        luaL_errorL(L, "the argument on the stack is not a Target object");
    return storage->get();
}

// BreakpointStatus is
// "pendingInstall" | "pendingUninstall" | "installed" | "invalid"
static const char* breakpointStatusToString(BreakpointStatus status)
{
    switch (status)
    {
    case BreakpointStatus::PendingInstall:
        return "pendingInstall";
    case BreakpointStatus::PendingUninstall:
        return "pendingUninstall";
    case BreakpointStatus::Installed:
        return "installed";
    case BreakpointStatus::Invalid:
        return "invalid";
    }
    LUTE_ASSERT(false);
    LUTE_UNREACHABLE();
}

static BreakpointStatus breakpointStringToStatus(const char* status)
{
    if (strcmp(status, "pendingInstall") == 0)
        return BreakpointStatus::PendingInstall;
    if (strcmp(status, "pendingUninstall") == 0)
        return BreakpointStatus::PendingUninstall;
    if (strcmp(status, "installed") == 0)
        return BreakpointStatus::Installed;
    if (strcmp(status, "invalid") == 0)
        return BreakpointStatus::Invalid;
    LUTE_ASSERT(false);
    LUTE_UNREACHABLE();
}

// Helper to push a Breakpoint type, which is
// id: number
// line: number
// sourcePath: string
// status: BreakpointStatus
static int pushBreakpoint(lua_State* L, const Breakpoint& bp)
{
    checkStack(L, 2);
    lua_createtable(L, 0, 4);
    lua_pushinteger(L, bp.id);
    lua_setfield(L, -2, "id");
    lua_pushinteger(L, bp.line);
    lua_setfield(L, -2, "line");
    lua_pushstring(L, bp.sourcePath.c_str());
    lua_setfield(L, -2, "sourcePath");
    lua_pushstring(L, breakpointStatusToString(bp.status));
    lua_setfield(L, -2, "status");
    return 1;
}

// Helper to push a Thread type, which is
// id: number
// name: string
static int pushThread(lua_State* L, const debug::Thread& thread)
{
    checkStack(L, 2);
    lua_createtable(L, 0, 2);
    lua_pushinteger(L, thread.id);
    lua_setfield(L, -2, "id");
    lua_pushstring(L, thread.name.c_str());
    lua_setfield(L, -2, "name");
    return 1;
}

// target.setBreakpoint(string sourcePath, int line)
// returns a breakpoint
static int target_setBreakpoint(lua_State* L)
{
    Target* target = getTarget(L, 1);
    const char* source = luaL_checkstring(L, 2);
    int line = luaL_checkinteger(L, 3);
    Breakpoint bp = target->setBreakpoint(source, line);
    return pushBreakpoint(L, bp);
}

// target.removeBreakpoint(int id)
// returns a boolean
static int target_removeBreakpoint(lua_State* L)
{
    Target* target = getTarget(L, 1);
    int bpId = luaL_checkinteger(L, 2);
    bool removed = target->removeBreakpoint(bpId);
    checkStack(L, 1);
    lua_pushboolean(L, removed);
    return 1;
}

// target.getBreakpoints()
// returns a table of Breakpoints
static int target_getBreakpoints(lua_State* L)
{
    Target* target = getTarget(L, 1);
    std::vector<Breakpoint> breakpoints = target->getBreakpoints();
    checkStack(L, 1);
    lua_createtable(L, breakpoints.size(), 0);
    for (int i = 0; i < (int)breakpoints.size(); i++)
    {
        pushBreakpoint(L, breakpoints[i]);
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

// target.getBreakpointsByStatus(BreakpointStatus status)
// returns a table of Breakpoints
static int target_getBreakpointsByStatus(lua_State* L)
{
    Target* target = getTarget(L, 1);
    const char* statusStr = luaL_checkstring(L, 2);
    BreakpointStatus status = breakpointStringToStatus(statusStr);
    std::vector<Breakpoint> breakpoints = target->getBreakpointsByStatus(status);
    checkStack(L, 1);
    lua_createtable(L, breakpoints.size(), 0);
    for (int i = 0; i < (int)breakpoints.size(); i++)
    {
        pushBreakpoint(L, breakpoints[i]);
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}


// target.getBreakpointById(int bpId)
// returns Breakpoint | nil
static int target_getBreakpointById(lua_State* L)
{
    Target* target = getTarget(L, 1);
    int id = luaL_checkinteger(L, 2);
    std::optional<Breakpoint> bp = target->getBreakpointById(id);
    if (!bp)
    {
        checkStack(L, 1);
        lua_pushnil(L);
        return 1;
    }
    return pushBreakpoint(L, *bp);
}


// target.getBreakpointBySourceLine(string sourcePath, int line)
// returns Breakpoint | nil
static int target_getBreakpointBySourceLine(lua_State* L)
{
    Target* target = getTarget(L, 1);
    const char* source = luaL_checkstring(L, 2);
    int line = luaL_checkinteger(L, 3);
    std::optional<Breakpoint> bp = target->getBreakpointBySourceLine(source, line);
    if (!bp)
    {
        checkStack(L, 1);
        lua_pushnil(L);
        return 1;
    }
    return pushBreakpoint(L, *bp);
}

// target.getLoadedSources()
// returns a table of strings
static int target_getLoadedSources(lua_State* L)
{
    Target* target = getTarget(L, 1);
    std::vector<std::string> sources = target->getLoadedSources();
    checkStack(L, 2);
    lua_createtable(L, sources.size(), 0);
    for (int i = 0; i < (int)sources.size(); i++)
    {
        lua_pushstring(L, sources[i].c_str());
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

// target.getThreads()
// returns a table of Threads
static int target_getThreads(lua_State* L)
{
    auto target = getTarget(L, 1);
    const std::vector<debug::Thread>& threads = target->getThreads();
    checkStack(L, 1);
    lua_createtable(L, threads.size(), 0);
    for (int i = 0; i < (int)threads.size(); i++)
    {
        pushThread(L, threads.at(i));
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

// target.getMainThread()
// returns Thread | nil
static int target_getMainThread(lua_State* L)
{
    auto target = getTarget(L, 1);
    std::optional<Thread> thread = target->getMainThread();
    checkStack(L, 1);
    if (!thread)
    {
        checkStack(L, 1);
        lua_pushnil(L);
        return 1;
    }
    return pushThread(L, *thread);
}

// target.getStoppedThread()
// returns Thread | nil
static int target_getStoppedThread(lua_State* L)
{
    auto target = getTarget(L, 1);
    std::optional<Thread> thread = target->getStoppedThread();
    checkStack(L, 1);
    if (!thread)
    {
        checkStack(L, 1);
        lua_pushnil(L);
        return 1;
    }
    return pushThread(L, *thread);
}

static std::shared_ptr<Ref> getOptionalCallback(lua_State* L, int tableIndex, const char* field)
{
    lua_getfield(L, tableIndex, field);
    std::shared_ptr<Ref> ref;
    if (lua_isfunction(L, -1))
        ref = std::make_shared<Ref>(L, -1);
    lua_pop(L, 1);
    return ref;
}

static std::function<void(const Breakpoint&)> makeBreakpointCallback(std::shared_ptr<Ref> ref, Runtime* runtime)
{
    return [ref, runtime](const Breakpoint& bp)
    {
        runtime->scheduleLuauCallback(
            ref,
            [bp](lua_State* L)
            {
                pushBreakpoint(L, bp);
                return 1;
            }
        );
    };
}

// target.launch(string sourcePath, vector<string> args, LaunchConfig callbacks) where
// LaunchConfig = {
//     onBreakpointHit(Thread thread, Breakpoint bp) -> ()
//     onBreakpointInstall(Breakpoint bp) -> ()
//     onBreakpointUninstall(Breakpoint bp) -> ()
//     onExit(bool success) -> ()
//     onPause(Thread thread) -> ()
//     onPrint(string message, string source, int line) -> ()
// }
// returns boolean
static int target_launch(lua_State* L)
{
    Target* target = getTarget(L, 1);

    const char* source = luaL_checkstring(L, 2);

    // read args from index 3
    std::vector<std::string> args;
    if (lua_istable(L, 3))
    {
        int n = lua_objlen(L, 3);
        for (int i = 1; i <= n; i++)
        {
            lua_rawgeti(L, 3, i);
            args.emplace_back(luaL_checkstring(L, -1));
            lua_pop(L, 1);
        }
    }

    // read callbacks from index 4 (optional table)
    LaunchConfig config;
    Runtime* runtime = getRuntime(L);
    if (lua_istable(L, 4))
    {
        // all of these schedule the handler to run on the parent runtime queue.
        if (auto ref = getOptionalCallback(L, 4, "onBreakpointHit"))
            config.onBreakpointHit = [ref, runtime](const Thread& thread, const Breakpoint& bp)
            {
                runtime->scheduleLuauCallback(
                    ref,
                    [thread, bp](lua_State* L)
                    {
                        pushThread(L, thread);
                        pushBreakpoint(L, bp);
                        return 2;
                    }
                );
            };
        if (auto ref = getOptionalCallback(L, 4, "onBreakpointInstall"))
            config.onBreakpointInstall = makeBreakpointCallback(ref, runtime);
        if (auto ref = getOptionalCallback(L, 4, "onBreakpointUninstall"))
            config.onBreakpointUninstall = makeBreakpointCallback(ref, runtime);
        if (auto ref = getOptionalCallback(L, 4, "onExit"))
        {
            config.onExit = [ref, runtime](bool success)
            {
                runtime->scheduleLuauCallback(
                    ref,
                    [success](lua_State* L)
                    {
                        checkStack(L, 1);
                        lua_pushboolean(L, success);
                        return 1;
                    }
                );
            };
        }
        if (auto ref = getOptionalCallback(L, 4, "onPause"))
        {
            config.onPause = [ref, runtime](const Thread& thread)
            {
                runtime->scheduleLuauCallback(
                    ref,
                    [thread](lua_State* L)
                    {
                        pushThread(L, thread);
                        return 1;
                    }
                );
            };
        }
        if (auto ref = getOptionalCallback(L, 4, "onPrint"))
        {
            config.onPrint = [ref, runtime](std::string message, std::string source, int line)
            {
                runtime->scheduleLuauCallback(
                    ref,
                    [message, source, line](lua_State* L)
                    {
                        checkStack(L, 3);
                        lua_pushstring(L, message.c_str());
                        lua_pushstring(L, source.c_str());
                        lua_pushinteger(L, line);
                        return 3;
                    }
                );
            };
        }
    }
    bool launched = target->launch(source, args, config);
    checkStack(L, 1);
    lua_pushboolean(L, launched);
    return 1;
}

// target.continueProcess()
// returns boolean
static int target_continueProcess(lua_State* L)
{
    Target* target = getTarget(L, 1);
    bool continued = target->continueProcess();
    checkStack(L, 1);
    lua_pushboolean(L, continued);
    return 1;
}

// target.continueProcess()
// returns boolean
static int target_pauseProcess(lua_State* L)
{
    Target* target = getTarget(L, 1);
    bool paused = target->pauseProcess();
    checkStack(L, 1);
    lua_pushboolean(L, paused);
    return 1;
}

// debugger.newTarget()
// returns Target
static int debug_newTarget(lua_State* L)
{
    Runtime* runtime = getRuntime(L);
    auto target = std::make_shared<Target>(*runtime);
    checkStack(L, 1);
    new (lua_newuserdatataggedwithmetatable(L, sizeof(std::shared_ptr<Target>), kTargetTag)) std::shared_ptr<Target>(std::move(target));
    return 1;
}
} // namespace debug

static const std::unordered_map<std::string, lua_CFunction> kTargetMethods = {
    {"setBreakpoint", debug::target_setBreakpoint},
    {"removeBreakpoint", debug::target_removeBreakpoint},
    {"getBreakpoints", debug::target_getBreakpoints},
    {"getBreakpointsByStatus", debug::target_getBreakpointsByStatus},
    {"getBreakpointById", debug::target_getBreakpointById},
    {"getBreakpointBySourceLine", debug::target_getBreakpointBySourceLine},
    {"launch", debug::target_launch},
    {"continueProcess", debug::target_continueProcess},
    {"pauseProcess", debug::target_pauseProcess},
    {"getLoadedSources", debug::target_getLoadedSources},
    {"getThreads", debug::target_getThreads},
    {"getMainThread", debug::target_getMainThread},
    {"getStoppedThread", debug::target_getStoppedThread},
};

static void initializeTarget(lua_State* L)
{
    checkStack(L, 3);
    luaL_newmetatable(L, "Target");

    lua_createtable(L, 0, kTargetMethods.size());
    for (auto [methodName, function] : kTargetMethods)
    {
        lua_pushcfunction(L, function, methodName.c_str());
        lua_setfield(L, -2, methodName.c_str());
    }
    lua_setfield(L, -2, "__index");

    lua_pushstring(L, "Target");
    lua_setfield(L, -2, "__type");

    lua_setuserdatadtor(
        L,
        kTargetTag,
        [](lua_State*, void* ud)
        {
            std::destroy_at(static_cast<std::shared_ptr<debug::Target>*>(ud));
        }
    );

    lua_setuserdatametatable(L, kTargetTag);
}

const char* const Debugger::properties[] = {nullptr};

const luaL_Reg Debugger::lib[] = {
    {"newTarget", debug::debug_newTarget},
    {nullptr, nullptr},
};

int Debugger::pushLibrary(lua_State* L)
{
    initializeTarget(L);
    checkStack(L, 2);
    lua_createtable(L, 0, std::size(Debugger::lib));
    for (auto& [name, func] : Debugger::lib)
    {
        if (!name || !func)
            break;
        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }
    lua_setreadonly(L, -1, 1);
    return 1;
}

LUTE_API int luaopen_debugger(lua_State* L)
{
    return Debugger::openAsGlobal(L);
}

LUTE_API int luteopen_debugger(lua_State* L)
{
    return Debugger::pushLibrary(L);
}
