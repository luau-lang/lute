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

// VariableScopeType is
// "locals" | "upvalues" | "table"
static const char* scopeTypeToString(debug::VariableScopeType type)
{
    switch (type)
    {
    case debug::VariableScopeType::Locals:
        return "locals";
    case debug::VariableScopeType::Upvalues:
        return "upvalues";
    case debug::VariableScopeType::Table:
        return "table";
    }
    LUAU_ASSERT(false);
    LUAU_UNREACHABLE();
}

static debug::VariableScopeType scopeStringToType(const char* type)
{
    if (strcmp(type, "locals") == 0)
        return debug::VariableScopeType::Locals;
    if (strcmp(type, "upvalues") == 0)
        return debug::VariableScopeType::Upvalues;
    if (strcmp(type, "table") == 0)
        return debug::VariableScopeType::Table;
    LUAU_ASSERT(false);
    LUAU_UNREACHABLE();
}

// StepType is
// "stepIn" | "stepOver" | "stepOut"
static const char* stepTypeToString(StepType type)
{
    switch (type)
    {
    case StepType::StepIn:
        return "stepIn";
    case StepType::StepOut:
        return "stepOut";
    case StepType::StepOver:
        return "stepOver";
    }
    LUTE_ASSERT(false);
    LUTE_UNREACHABLE();
}

static StepType stepStringToStatus(const char* status)
{
    if (strcmp(status, "stepIn") == 0)
        return StepType::StepIn;
    if (strcmp(status, "stepOut") == 0)
        return StepType::StepOut;
    if (strcmp(status, "stepOver") == 0)
        return StepType::StepOver;
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
static int pushThread(lua_State* L, const Thread& thread)
{
    checkStack(L, 2);
    lua_createtable(L, 0, 2);
    lua_pushinteger(L, thread.id);
    lua_setfield(L, -2, "id");
    lua_pushstring(L, thread.name.c_str());
    lua_setfield(L, -2, "name");
    return 1;
}

// Helper to push a StackFrame type, which is
// id: number
// name: string
// sourcePath: string
// line: number
// column: number
static int pushStackFrame(lua_State* L, const StackFrame& frame)
{
    checkStack(L, 2);
    lua_createtable(L, 0, 5);
    lua_pushinteger(L, frame.id);
    lua_setfield(L, -2, "id");
    lua_pushstring(L, frame.name.c_str());
    lua_setfield(L, -2, "name");
    lua_pushstring(L, frame.sourcePath.c_str());
    lua_setfield(L, -2, "sourcePath");
    lua_pushinteger(L, frame.line);
    lua_setfield(L, -2, "line");
    lua_pushinteger(L, frame.column);
    lua_setfield(L, -2, "column");
    return 1;
}

// Helper to push a VariableScope type, which is
// variableRef: number
// type: string
// name: string
// threadId: number
// level: number
static int pushVariableScope(lua_State* L, const debug::VariableScope& scope)
{
    checkStack(L, 2);
    lua_createtable(L, 0, 5);
    lua_pushinteger(L, scope.variableReference);
    lua_setfield(L, -2, "variableRef");
    lua_pushstring(L, scopeTypeToString(scope.type));
    lua_setfield(L, -2, "type");
    lua_pushstring(L, scope.name.c_str());
    lua_setfield(L, -2, "name");
    lua_pushinteger(L, scope.threadId);
    lua_setfield(L, -2, "threadId");
    lua_pushinteger(L, scope.level);
    lua_setfield(L, -2, "level");
    return 1;
}

// Helper to push a Variable type, which is
// name: string
// value: string
// type: string
// variableRef: number
static int pushVariable(lua_State* L, const debug::Variable& variable)
{
    checkStack(L, 2);
    lua_createtable(L, 0, 4);
    lua_pushstring(L, variable.name.c_str());
    lua_setfield(L, -2, "name");
    lua_pushstring(L, variable.value.c_str());
    lua_setfield(L, -2, "value");
    lua_pushstring(L, variable.type.c_str());
    lua_setfield(L, -2, "type");
    lua_pushinteger(L, variable.variableReference);
    lua_setfield(L, -2, "variableRef");
    return 1;
}

// Helper to push a StepInfo type, which is
// type: StepType
// startLine: int
// startDepth: int
static int pushStepInfo(lua_State* L, const StepInfo& stepInfo)
{
    checkStack(L, 2);
    lua_createtable(L, 0, 3);
    lua_pushstring(L, stepTypeToString(stepInfo.type));
    lua_setfield(L, -2, "type");
    lua_pushinteger(L, stepInfo.startLine);
    lua_setfield(L, -2, "startLine");
    lua_pushinteger(L, stepInfo.startDepth);
    lua_setfield(L, -2, "startDepth");
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

// target.step(int threadId, StepType type)
// returns a boolean
static int target_step(lua_State* L)
{
    Target* target = getTarget(L, 1);
    int threadId = luaL_checkinteger(L, 2);
    const char* statusStr = luaL_checkstring(L, 3);
    StepType type = stepStringToStatus(statusStr);
    bool step = target->step(threadId, type);
    checkStack(L, 1);
    lua_pushboolean(L, step);
    return 1;
}

// target.stepIn(int threadId)
// returns a boolean
static int target_stepIn(lua_State* L)
{
    Target* target = getTarget(L, 1);
    int threadId = luaL_checkinteger(L, 2);
    bool step = target->stepIn(threadId);
    checkStack(L, 1);
    lua_pushboolean(L, step);
    return 1;
}

// target.stepOut(int threadId)
// returns a boolean
static int target_stepOut(lua_State* L)
{
    Target* target = getTarget(L, 1);
    int threadId = luaL_checkinteger(L, 2);
    bool step = target->stepOut(threadId);
    checkStack(L, 1);
    lua_pushboolean(L, step);
    return 1;
}

// target.stepOver()
// returns a boolean
static int target_stepOver(lua_State* L)
{
    Target* target = getTarget(L, 1);
    int threadId = luaL_checkinteger(L, 2);
    bool step = target->stepOver(threadId);
    checkStack(L, 1);
    lua_pushboolean(L, step);
    return 1;
}

// target.getStoppedLocation()
// returns a (string, integer) | (nil, nil)
static int target_getStoppedLocation(lua_State* L)
{
    Target* target = getTarget(L, 1);
    std::optional<std::pair<std::string, int>> stoppedLocation = target->getStoppedLocation();
    if (!stoppedLocation)
    {
        checkStack(L, 2);
        lua_pushnil(L);
        lua_pushnil(L);
        return 2;
    }
    checkStack(L, 2);
    lua_pushstring(L, stoppedLocation->first.c_str());
    lua_pushinteger(L, stoppedLocation->second);
    return 2;
}

// target.getThreads()
// returns a table of Threads
static int target_getThreads(lua_State* L)
{
    auto target = getTarget(L, 1);
    const std::vector<Thread>& threads = target->getThreads();
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

// target.getStackDepth(int threadId)
// return an integer
static int target_getStackDepth(lua_State* L)
{
    auto target = getTarget(L, 1);
    int threadId = luaL_checkinteger(L, 2);
    int depth = target->getStackDepth(threadId);
    checkStack(L, 1);
    lua_pushinteger(L, depth);
    return 1;
}

// target.getStackFrame(int threadId, int level)
// return StackFrame | nil
static int target_getStackFrame(lua_State* L)
{
    auto target = getTarget(L, 1);
    int threadId = luaL_checkinteger(L, 2);
    int level = luaL_checkinteger(L, 3);
    std::optional<StackFrame> stackframe = target->getStackFrame(threadId, level);
    if (!stackframe)
    {
        checkStack(L, 1);
        lua_pushnil(L);
        return 1;
    }
    return pushStackFrame(L, *stackframe);
}

// target.getStackTrace(int threadId, int startLevel = 0, int numFrames = 0)
// return {StackFrame} | nil
static int target_getStackTrace(lua_State* L)
{
    auto target = getTarget(L, 1);
    int threadId = luaL_checkinteger(L, 2);
    int startLevel = (int)luaL_optinteger(L, 3, 0);
    int numFrames = (int)luaL_optinteger(L, 4, 0);
    std::optional<std::vector<StackFrame>> stackframes = target->getStackTrace(threadId, startLevel, numFrames);
    if (!stackframes)
    {
        checkStack(L, 1);
        lua_pushnil(L);
        return 1;
    }
    checkStack(L, 1);
    lua_createtable(L, stackframes->size(), 0);
    for (int i = 0; i < (int)stackframes->size(); i++)
    {
        pushStackFrame(L, stackframes->at(i));
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

// target.getScopes(int frameId)
// returns {VariableScoope} | nil
static int target_getScopes(lua_State* L)
{
    auto target = getTarget(L, 1);
    int frameId = luaL_checkinteger(L, 2);
    std::optional<std::vector<debug::VariableScope>> scopes = target->getScopes(frameId);
    if (!scopes)
    {
        checkStack(L, 1);
        lua_pushnil(L);
        return 1;
    }
    checkStack(L, 1);
    lua_createtable(L, scopes->size(), 0);
    for (int i = 0; i < (int)scopes->size(); i++)
    {
        pushVariableScope(L, scopes->at(i));
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

// target.getVariables(int variableRef)
// returns {Variable} | nil
static int target_getVariables(lua_State* L)
{
    auto target = getTarget(L, 1);
    int variableRef = luaL_checkinteger(L, 2);
    std::optional<std::vector<debug::Variable>> variables = target->getVariables(variableRef);
    if (!variables)
    {
        checkStack(L, 1);
        lua_pushnil(L);
        return 1;
    }
    checkStack(L, 1);
    lua_createtable(L, variables->size(), 0);
    for (int i = 0; i < (int)variables->size(); i++)
    {
        pushVariable(L, variables->at(i));
        lua_rawseti(L, -2, i + 1);
    }
    return 1;
}

// target.getVariablesByScopeType(int frameId, VariableScopeType scopeType)
// returns {Variable} | nil
static int target_getVariablesByScopeType(lua_State* L)
{
    auto target = getTarget(L, 1);
    int frameId = luaL_checkinteger(L, 2);
    const char* typeStr = luaL_checkstring(L, 3);
    debug::VariableScopeType type = scopeStringToType(typeStr);
    std::optional<std::vector<debug::Variable>> variables = target->getVariablesByScopeType(frameId, type);
    if (!variables)
    {
        checkStack(L, 1);
        lua_pushnil(L);
        return 1;
    }
    checkStack(L, 1);
    lua_createtable(L, variables->size(), 0);
    for (int i = 0; i < (int)variables->size(); i++)
    {
        pushVariable(L, variables->at(i));
        lua_rawseti(L, -2, i + 1);
    }
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
//     onStepStop(Thread thread, StepInfo stepInfo) -> ()
// }
// returns string | nil
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
        if (auto ref = getOptionalCallback(L, 4, "onStepStop"))
        {
            config.onStepStop = [ref, runtime](const Thread& thread, const StepInfo& stepInfo)
            {
                runtime->scheduleLuauCallback(
                    ref,
                    [thread, stepInfo](lua_State* L)
                    {
                        pushThread(L, thread);
                        pushStepInfo(L, stepInfo);
                        return 2;
                    }
                );
            };
        }
    }
    std::optional<std::string> error = target->launch(source, args, config);
    checkStack(L, 1);
    if (error)
        lua_pushstring(L, error->c_str());
    else
        lua_pushnil(L);
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
    {"step", debug::target_step},
    {"stepIn", debug::target_stepIn},
    {"stepOut", debug::target_stepOut},
    {"stepOver", debug::target_stepOver},
    {"getStoppedLocation", debug::target_getStoppedLocation},
    {"getThreads", debug::target_getThreads},
    {"getMainThread", debug::target_getMainThread},
    {"getStoppedThread", debug::target_getStoppedThread},
    {"getStackDepth", debug::target_getStackDepth},
    {"getStackFrame", debug::target_getStackFrame},
    {"getStackTrace", debug::target_getStackTrace},
    {"getScopes", debug::target_getScopes},
    {"getVariables", debug::target_getVariables},
    {"getVariablesByScopeType", debug::target_getVariablesByScopeType},
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
