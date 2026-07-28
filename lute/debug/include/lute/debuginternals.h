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

struct Breakpoint
{
    int id;
    // This will use forward slashes instead of backwards.
    std::string sourcePath;
    int line;
    BreakpointStatus status;
    explicit Breakpoint(int id, std::string sourcePath, int line, BreakpointStatus status);
};

// Each Thread represents one coroutine in our Lute runtime.
struct Thread
{
    int id = -1;
    std::string name;
    Thread() = default; // for unordered_map
    Thread(int id, std::string name);
    bool operator==(const Thread& other) const;
};

struct LaunchConfig
{
    // onBreakpointInstall is called whenever an installation attempt is actually made, regardless
    // of whether it resulted in being installed or the bp being invalid.
    std::function<void(const Breakpoint& bp)> onBreakpointInstall;
    std::function<void(const Breakpoint& bp)> onBreakpointUninstall;
    std::function<void(const Thread& thread, const Breakpoint& bp)> onBreakpointHit;
    std::function<void(bool success)> onExit;
    std::function<void(const Thread& thread)> onPause;
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
    Breakpoint setBreakpoint(std::string sourcePath, int line);
    bool removeBreakpoint(int bpId);

    std::vector<Breakpoint> getBreakpoints() const;
    std::vector<Breakpoint> getBreakpointsByStatus(BreakpointStatus status) const;
    std::optional<Breakpoint> getBreakpointById(int breakpointId) const;
    std::optional<Breakpoint> getBreakpointBySourceLine(std::string source, int line) const;

    // For inspection while paused:
    // About multiple coroutines: we don't currently handle the original implementation of task.spawn(). Calling
    // task.spawn() when working in the debugger instead calls task.defer() instead.
    // The difference is that the original task.spawn() tries to run the coroutine inline with our current execution, resulting
    // in issues when trying to pause. Similar methods that also run coroutines inline with our current execution will not work.
    // In contrast, in task.defer(), the coroutine is added to set of running coroutines but execution
    // is deferred. Our pause mechanism will then work correctly.
    std::vector<Thread> getThreads() const;

    // For actively running scripts:
    bool launch(std::string sourcePath, const std::vector<std::string>& args, LaunchConfig config = {});
    bool continueProcess();
    bool pauseProcess();

private:
    // targetMutex protects the entire Target, since Target can be accessed from the main thread
    // and the child runtime thread (i.e. in the debugbreak breakpoint callback).
    // This is ok because we are not looking for high performance but rather correctness.
    mutable std::mutex targetMutex;

    Runtime& parentRuntime;
    std::unique_ptr<Runtime> childRuntime;

    int currentBreakpointId = 0;
    bool paused = true;
    bool launched = false;
    std::unordered_map<int, Breakpoint> breakpoints;    // breakpoint id -> breakpoint object (this is unordered_map to support erase)
    std::unordered_set<lua_State*> continueRequestedBp; // if the thread's lua_State* is in this set, we skip the next bp it hits
    std::optional<Breakpoint> bpHit;
    LaunchConfig launchConfig;

    Luau::DenseHashMap<std::string, std::shared_ptr<Ref>> loadedSources; // source path -> reference to chunk

    // thread for our launched script
    lua_State* scriptThread = nullptr;

    // our stopped thread that we need to requeue when we continue
    lua_State* stoppedThread = nullptr;

    // for require contexts
    std::unique_ptr<RequireCtx> requireCtx;

    // thread information
    int threadId = 0;
    std::unordered_map<lua_State*, Thread> stateToThread; // lua_State* -> thread information about that state
    std::unordered_map<int, lua_State*> threadIdToState;  // thread id -> lua_State*

    // private methods are meant for internal calls, so these don't lock targetMutex
    std::optional<Breakpoint> getBreakpointBySourceLineHelper(std::string source, int line) const;
    std::optional<Breakpoint> getBreakpointByIdHelper(int breakpointId) const;

    bool installBreakpoint(lua_State* L, Breakpoint& bp);
    bool uninstallBreakpoint(lua_State* L, Breakpoint& bp);
    std::pair<std::vector<Breakpoint>, std::vector<Breakpoint>> modifyPendingBreakpoints(lua_State* L);

    void installBpHitCallback();
    void installExitCallback();
    void installThreadCallback();
};
} // namespace debug
