#include "lute/debug.h"

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

static debug::Target* getTarget(lua_State* L, int index)
{
    auto* storage = static_cast<std::shared_ptr<debug::Target>*>(lua_touserdatatagged(L, index, kTargetTag));
    if (!storage || !*storage)
        luaL_errorL(L, "invalid target");
    return storage->get();
}
static const char* breakpointStatusToString(debug::BreakpointStatus status)
{
    switch (status)
    {
    case debug::BreakpointStatus::PendingInstall:
        return "pendingInstall";
    case debug::BreakpointStatus::PendingUninstall:
        return "pendingUninstall";
    case debug::BreakpointStatus::Installed:
        return "installed";
    case debug::BreakpointStatus::Invalid:
        return "invalid";
    }
    return "unknown";
}

static debug::BreakpointStatus breakpointStringToStatus(const char* status)
{
    if (strcmp(status, "pendingInstall") == 0)
        return debug::BreakpointStatus::PendingInstall;
    if (strcmp(status, "pendingUninstall") == 0)
        return debug::BreakpointStatus::PendingUninstall;
    if (strcmp(status, "installed") == 0)
        return debug::BreakpointStatus::Installed;
    if (strcmp(status, "invalid") == 0)
        return debug::BreakpointStatus::Invalid;
    // on unknown status, simply return that bp is invalid
    return debug::BreakpointStatus::Invalid;
}

static void pushBreakpoint(lua_State* L, const debug::Breakpoint& bp)
{
    lua_createtable(L, 0, 4);
    lua_pushinteger(L, bp.id);
    lua_setfield(L, -2, "id");
    lua_pushinteger(L, bp.line);
    lua_setfield(L, -2, "line");
    lua_pushstring(L, bp.sourcePath.c_str());
    lua_setfield(L, -2, "sourcePath");
    lua_pushstring(L, breakpointStatusToString(bp.status));
    lua_setfield(L, -2, "status");
}

static int target_setBreakpoint(lua_State* L)
{
    debug::Target* target = getTarget(L, 1);
    const char* source = luaL_checkstring(L, 2);
    int line = luaL_checkinteger(L, 3);
    debug::Breakpoint bp = target->setBreakpoint(source, line);
    pushBreakpoint(L, bp);
    return 1;
}

static int target_removeBreakpoint(lua_State* L)
{
    debug::Target* target = getTarget(L, 1);
    int bpId = luaL_checkinteger(L, 2);
    bool removed = target->removeBreakpoint(bpId);
    lua_pushboolean(L, removed);
    return 1;
}

static int target_getBreakpoints(lua_State* L)
{
    debug::Target* target = getTarget(L, 1);
    std::vector<debug::Breakpoint> breakpoints = target->getBreakpoints();
    lua_createtable(L, breakpoints.size(), 0);
    for (int i = 0; i < (int)breakpoints.size(); i++)
    {
        pushBreakpoint(L, breakpoints[i]);
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

static int target_getBreakpointsByStatus(lua_State* L)
{
    debug::Target* target = getTarget(L, 1);
    const char* statusStr = luaL_checkstring(L, 2);
    debug::BreakpointStatus status = breakpointStringToStatus(statusStr);
    std::vector<debug::Breakpoint> breakpoints = target->getBreakpointsByStatus(status);
    lua_createtable(L, breakpoints.size(), 0);
    for (int i = 0; i < (int)breakpoints.size(); i++)
    {
        pushBreakpoint(L, breakpoints[i]);
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

static int target_getBreakpointById(lua_State* L)
{
    debug::Target* target = getTarget(L, 1);
    int id = luaL_checkinteger(L, 2);
    std::optional<debug::Breakpoint> bp = target->getBreakpointById(id);
    if (!bp)
    {
        lua_pushnil(L);
        return 1;
    }
    pushBreakpoint(L, *bp);
    return 1;
}

static int target_getBreakpointBySourceLine(lua_State* L)
{
    debug::Target* target = getTarget(L, 1);
    const char* source = luaL_checkstring(L, 2);
    int line = luaL_checkinteger(L, 3);
    std::optional<debug::Breakpoint> bp = target->getBreakpointBySourceLine(source, line);
    if (!bp)
    {
        lua_pushnil(L);
        return 1;
    }
    pushBreakpoint(L, *bp);
    return 1;
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

static int target_launch(lua_State* L)
{
    debug::Target* target = getTarget(L, 1);

    const char* source = luaL_checkstring(L, 2);

    // read args from index 3
    std::vector<std::string> args;
    if (lua_istable(L, 3))
    {
        int n = lua_objlen(L, 3);
        for (int i = 1; i <= n; i++)
        {
            lua_rawgeti(L, 3, i);
            args.push_back(luaL_checkstring(L, -1));
            lua_pop(L, 1);
        }
    }

    // read callbacks from index 4 (optional table)
    debug::LaunchConfig config;
    Runtime* runtime = getRuntime(L);
    if (lua_istable(L, 4))
    {
        if (auto ref = getOptionalCallback(L, 4, "onBreakpointHit"))
        {
            // this schedules the handler to run on the parent runtime queue.
            config.onBreakpointHit = [ref, runtime](const debug::Breakpoint& bp)
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
        if (auto ref = getOptionalCallback(L, 4, "onBreakpointInstall"))
        {
            config.onBreakpointInstall = [ref, runtime](const debug::Breakpoint& bp)
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
        if (auto ref = getOptionalCallback(L, 4, "onBreakpointUninstall"))
        {
            config.onBreakpointUninstall = [ref, runtime](const debug::Breakpoint& bp)
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
        if (auto ref = getOptionalCallback(L, 4, "onExit"))
        {
            config.onExit = [ref, runtime](bool success)
            {
                runtime->scheduleLuauCallback(
                    ref,
                    [success](lua_State* L)
                    {
                        lua_pushboolean(L, success);
                        return 1;
                    }
                );
            };
        }
    }
    bool removed = target->launch(source, args, config);
    lua_pushboolean(L, removed);
    return 1;
}

static int target_continueProcess(lua_State* L)
{
    auto target = getTarget(L, 1);
    bool continued = target->continueProcess();
    lua_pushboolean(L, continued);
    return 1;
}

static int debug_newTarget(lua_State* L)
{
    Runtime* runtime = getRuntime(L);
    auto target = std::make_shared<debug::Target>(*runtime);
    new (lua_newuserdatataggedwithmetatable(L, sizeof(std::shared_ptr<debug::Target>), kTargetTag)) std::shared_ptr<debug::Target>(std::move(target));
    return 1;
}

static const std::unordered_map<std::string, lua_CFunction> kTargetMethods = {
    {"setBreakpoint", target_setBreakpoint},
    {"removeBreakpoint", target_removeBreakpoint},
    {"getBreakpoints", target_getBreakpoints},
    {"getBreakpointsByStatus", target_getBreakpointsByStatus},
    {"getBreakpointById", target_getBreakpointById},
    {"getBreakpointBySourceLine", target_getBreakpointBySourceLine},
    {"launch", target_launch},
    {"continueProcess", target_continueProcess}
};

static void initializeTarget(lua_State* L)
{
    luaL_newmetatable(L, "Target");

    lua_pushcfunction(
        L,
        [](lua_State* L)
        {
            const char* index = luaL_checkstring(L, -1);
            auto it = kTargetMethods.find(index);
            if (it != kTargetMethods.end())
            {
                lua_pushcfunction(L, it->second, it->first.c_str());
                return 1;
            }
            return 0;
        },
        "Target.__index"
    );
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


const luaL_Reg Debug::lib[] = {
    {"newTarget", debug_newTarget},
    {nullptr, nullptr},
};

int Debug::pushLibrary(lua_State* L)
{
    initializeTarget(L);
    lua_createtable(L, 0, std::size(Debug::lib));
    for (auto& [name, func] : Debug::lib)
    {
        if (!name || !func)
            break;
        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }
    lua_setreadonly(L, -1, 1);
    return 1;
}

LUTE_API int luaopen_debug_lute(lua_State* L)
{
    return Debug::openAsGlobal(L);
}

LUTE_API int luteopen_debug(lua_State* L)
{
    return Debug::pushLibrary(L);
}
