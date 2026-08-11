#pragma once

#include "lute/require.h"
#include "lute/runtime.h"

#include "Luau/DenseHash.h"

#include <functional>
#include <mutex>
#include <optional>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <variant>
#include <vector>

struct lua_State;
struct lua_Debug;

namespace debug
{
enum class BreakpointStatus
{
    PendingInstall,
    PendingUninstall,
    Installed,
    Invalid,
};

struct BreakpointConfig
{
    std::string condition = "";
    std::string hitCondition = "";
    std::string logMessage = "";
};

struct Breakpoint
{
    int id;
    // This will use forward slashes instead of backwards.
    std::string sourcePath;
    int line;
    std::string condition;
    std::string hitCondition;
    int hitCount = 0;
    std::string logMessage;
    BreakpointStatus status;
    Breakpoint(int id, std::string sourcePath, int line, BreakpointConfig config, BreakpointStatus status);
};

// Exception breakpoints act as filters, so only if uncaughtExceptions or caughtExceptions
// is true do we surface these exceptions.
struct ExceptionBreakpointInfo
{
    bool uncaughtExceptions;
    const int uncaughtId = -1;
    bool caughtExceptions;
    const int caughtId = -2;
    ExceptionBreakpointInfo(bool uncaughtExceptions, bool caughtExceptions);
};

// Each Thread represents one coroutine in our Lute runtime.
struct Thread
{
    int id = -1;
    std::string name;
    Thread(int id, std::string name);
    bool operator==(const Thread& other) const;
};

struct StackFrame
{
    int id = -1;
    std::string name;
    std::string sourcePath;
    int line = 0;
    int column = 0;
};

enum class VariableScopeType
{
    Local,
    Upvalue,
    Global,
    Table
};

// A VariableScope corresponds to an object with a variable reference.
// Locals and upvalues are returned by the getScope() method. After calling getVariable,
// we can use variable reference IDs to drill into tables if necessary.
struct VariableScope
{
    int variableReference;
    VariableScopeType type;
    std::string name;
    int threadId;
    int level;
    int luaref; // for tables

    explicit VariableScope(int variableReference, VariableScopeType type, std::string name, int threadId = -1, int level = -1, int luaref = -1);
    static VariableScope makeLocals(int variableReference, int threadId, int level);
    static VariableScope makeUpvalues(int variableReference, int threadId, int level);
    static VariableScope makeGlobals(int variableReference, int threadId, int level);
    static VariableScope makeTable(int variableReference, int threadId, int level, int luaref);
};

// Variables are generally returned by the getVariable() method. They only have
// a reference ID if they represent a table.
struct Variable
{
    std::string name;
    // a one line representation, especially if variable is a table
    std::string value;
    std::string type;
    int variableReference = 0;
    bool isTruthy();
};

using EvaluateResult = std::variant<Variable, std::string>;

enum class StepType
{
    StepOver,
    StepIn,
    StepOut,
};

struct StepInfo
{
    Thread thread;
    StepType type;
    int startLine;
    int startDepth;
};

struct LaunchConfig
{
    // onBreakpointInstall is called whenever an installation attempt is actually made, regardless
    // of whether it resulted in being installed or the bp being invalid.
    std::function<void(const Breakpoint& bp)> onBreakpointInstall;
    std::function<void(const Breakpoint& bp)> onBreakpointUninstall;
    std::function<void(const Thread& thread, const Breakpoint& bp)> onBreakpointHit;
    std::function<void(const std::string& message, const Breakpoint& bp)> onLogpointHit;
    std::function<void(bool success)> onExit;
    std::function<void(const Thread& thread)> onPause;
    std::function<void(const std::string& message, const std::string& source, int line)> onPrint;
    std::function<void(const Thread& thread, const StepInfo& stepInfo)> onStepStop;
    std::function<void(const Thread& thread, int bpId, const std::string& errorMessage)> onException;
    std::function<void(const std::string& source)> onSourceLoad;
};

struct Target
{
    explicit Target(Runtime& parentRuntime);
    ~Target();

    // Get list of sources, with sources using forward slahes consistently.
    // Our principle in path format is that we accept any path format as input but will
    // internally use and then output with paths that use exclusively forward slashes.
    std::vector<std::string> getLoadedSources();

    // Setting breakpoints is a two step process. We add them to our Target. If they
    // involve a source that has already been loaded by the VM, we attempt to install that
    // breakpoint. Otherwise, it exists as a pending breakpoint until new sources are loaded.
    // We do this because clients may 1) configure breakpoints before launching executables
    // 2) we load sources dynamically with @require that a client may want to debug.
    //
    // Guarantees for when breakpoints are installed:
    // Any breakpoint that is placed when the target process is paused (including before launch) and that
    // have a loaded source are guaranteed to be installed before the process is resumed. Breakpoints placed on a loaded source
    // when the target script is running may not be installed until the next time that script is paused.
    Breakpoint setBreakpoint(std::string sourcePath, int line, BreakpointConfig config = {});
    bool removeBreakpoint(int bpId);

    std::vector<Breakpoint> getBreakpoints() const;
    std::vector<Breakpoint> getBreakpointsByStatus(BreakpointStatus status) const;
    std::optional<Breakpoint> getBreakpointById(int breakpointId) const;
    std::optional<Breakpoint> getBreakpointBySourceLine(std::string source, int line) const;

    // Exception breakpoints are mostly separate from normal breakpoints. They have negative
    // breakpoint IDs for DAP purposes.
    ExceptionBreakpointInfo setExceptionBreakpoint(bool uncaught, bool caught);

    // For inspection:
    // About multiple coroutines: we don't currently handle the original implementation of task.spawn(). Calling
    // task.spawn() when working in the debugger instead calls task.defer() instead.
    // The difference is that the original task.spawn() tries to run the coroutine inline with our current execution, resulting
    // in issues when trying to pause. Similar methods that also run coroutines inline with our current execution will not work.
    // In contrast, in task.defer(), the coroutine is added to set of running coroutines but execution
    // is deferred. Our pause mechanism will then work correctly.
    std::optional<std::pair<std::string, int>> getStoppedLocation() const;
    int getStackDepth(int threadId);
    std::optional<Thread> getMainThread() const; // can be used when not paused
    std::optional<Thread> getStoppedThread() const;
    std::vector<Thread> getThreads() const; // can be used when not paused
    std::optional<StackFrame> getStackFrame(int threadId, int level);
    std::optional<std::vector<StackFrame>> getStackTrace(int threadId, int startLevel = 0, int maximumLevel = 0);
    std::optional<std::vector<VariableScope>> getScopes(int frameId);
    std::optional<std::vector<Variable>> getVariables(int varRef);
    std::optional<std::vector<Variable>> getVariablesByScopeType(int frameId, VariableScopeType contextType);

    // For evaluation:
    EvaluateResult evaluateExpression(std::string expression, int frameId = -1);
    EvaluateResult setVariable(int varRef, std::string varName, std::string setExpression);
    EvaluateResult setExpression(std::string lExpression, std::string setExpression, int frameId = -1);

    // For actively running scripts:
    std::optional<std::string> launch(std::string sourcePath, const std::vector<std::string>& args, LaunchConfig config = {});
    bool continueProcess();
    bool pauseProcess();
    bool step(int threadId, StepType type);
    bool stepIn(int threadId);
    bool stepOver(int threadId);
    bool stepOut(int threadId);

private:
    // targetMutex protects the entire Target, since Target can be accessed from the main thread
    // and the child runtime thread (i.e. in the debugbreak breakpoint callback).
    // This is ok because we are not looking for high performance but rather correctness.
    mutable std::mutex targetMutex;

    Runtime& parentRuntime;
    std::unique_ptr<Runtime> childRuntime;

    int currentBreakpointId = 1;
    bool paused = true;
    bool launched = false;
    std::unordered_map<int, Breakpoint> breakpoints;    // breakpoint id -> breakpoint object (this is unordered_map to support erase)
    std::unordered_set<lua_State*> continueRequestedBp; // if the thread's lua_State* is in this set, we skip the next bp it hits
    std::optional<Breakpoint> bpHit;
    ExceptionBreakpointInfo exceptionBpInfo;
    bool stoppedUncaughtException = false;
    LaunchConfig launchConfig;

    Luau::DenseHashMap<std::string, std::shared_ptr<Ref>> loadedSources; // source path -> reference to chunk

    // thread for our launched script
    lua_State* scriptThread = nullptr;
    std::shared_ptr<Ref> scriptThreadRef;

    // our stopped thread that we need to requeue when we continue
    bool stoppedNoYield = false;
    lua_State* stoppedThread = nullptr;
    std::shared_ptr<Ref> stoppedThreadRef;
    // Due to the way Lua debugger callbacks works, we need to set the stopped line/instruction in the callback. otherwise, outside of the callback,
    // lua_getinfo will return the previous line/instruction.
    int stoppedLine = -1;
    std::string stoppedLocation = "";
    const uint32_t* stoppedPc = nullptr;

    // for require contexts
    std::unique_ptr<RequireCtx> requireCtx;

    // thread information
    int threadId = 1;
    std::unordered_map<lua_State*, Thread> stateToThread; // lua_State* -> thread information about that state
    std::unordered_map<int, lua_State*> threadIdToState;  // thread id -> lua_State*

    // stack frame information
    // note: stack frames are copies between these two data structures, not pointers. That's ok because the debugger
    // should never modify the stack frames themselves.
    // stack frame ID information is reset upon every continue(). The base id resets to 1 as well.
    int stackframeId = 1;
    std::unordered_map<int, std::unordered_map<int, StackFrame>> stateToStackFrame; // thread id -> level -> stackFrame
    std::unordered_map<int, std::pair<int, int>> idToStackFrameInfo;                // stack frame id -> stack frame's (thread id, level)

    // variable information
    // scope and variable information also resets upon every continue(). The base id resets to 1.
    int variableRefId = 1;
    std::unordered_map<int, std::vector<VariableScope>> scopeCache; // stack frame id -> scope
    std::unordered_map<int, std::vector<Variable>> variableCache;   // var reference -> all variables under that reference
    std::unordered_map<int, VariableScope> variableContexts;        // var reference -> variableContext

    // only set when stepping
    std::optional<StepInfo> stepInfo;

    // private methods are meant for internal calls, so these don't lock targetMutex
    std::optional<Breakpoint> getBreakpointBySourceLineHelper(std::string source, int line) const;
    std::optional<Breakpoint> getBreakpointByIdHelper(int breakpointId) const;
    std::optional<StackFrame> getStackFrameHelper(int threadId, int level);
    std::optional<std::vector<VariableScope>> getScopesHelper(int threadId, int level);
    std::optional<std::vector<Variable>> getVariablesHelper(int varRef);
    EvaluateResult evaluateExpressionHelper(lua_State* contextThread, int contextLevel, std::string expression, lua_State* moveThread = nullptr);
    EvaluateResult setVariableHelper(VariableScope& context, std::string varName, std::string setExpression, int evalLevel = -1);
    void continueProcessHelper();

    bool installBreakpoint(lua_State* L, Breakpoint& bp);
    bool uninstallBreakpoint(lua_State* L, Breakpoint& bp);
    std::pair<std::vector<Breakpoint>, std::vector<Breakpoint>> modifyPendingBreakpoints(lua_State* L);

    // for conditional breakpoints:
    bool evaluateBpCondition(lua_State* L, const Breakpoint& bp);
    bool evaluateBpHitCondition(lua_State* L, const Breakpoint& bp);
    std::string evaluateLogMessage(lua_State* L, const Breakpoint& bp);

    void computeStoppedLocation(lua_State* L);
    void unsetStoppedLocation();    
    // Controls how stoppedSetState decides between the yielding and non-yielding stop pathways.
    enum class StopYieldMode
    {
        Auto,
        ForceNoYield,
        Neither,
    };
    void stoppedSetState(lua_State* L, StopYieldMode yieldMode = StopYieldMode::Auto);
    void stoppedDispatchCallback(std::function<void()> debugStopCallback);

    Variable makeVariable(lua_State* L, const std::string& name);
    std::vector<Variable> getLocalsHelper(lua_State* L, int level);
    std::vector<Variable> getUpvaluesHelper(lua_State* L, int level);
    std::vector<Variable> getGlobalsHelper(lua_State* L, int level);
    std::vector<Variable> getTableHelper(lua_State* L, int idx);

    void injectLocals(lua_State* L, int level, lua_State* eval, int evalTableIndex);
    void injectUpvalues(lua_State* L, int level, lua_State* eval, int evalTableIndex);

    EvaluateResult setLocalsHelper(lua_State* L, int contextLevel, std::string setName, std::string value, int evalLevel);
    EvaluateResult setUpvaluesHelper(lua_State* L, int contextLevel, std::string setName, std::string value, int evalLevel);

    void installBpHitCallback();
    void installExitCallback();
    void installThreadCallback();
    void installExceptionCallback();

    static int replacePrint(lua_State* L);
};
} // namespace debug
