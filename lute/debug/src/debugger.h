#pragma once

#include "lute/runtime.h"

#include "Luau/DenseHash.h"

#include <functional>
#include <mutex>
#include <optional>
#include <string>
#include <unordered_map>
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
    std::string sourcePath;
    int line;
    BreakpointStatus status;
    explicit Breakpoint(int id, std::string sourcePath, int line, BreakpointStatus status);
};

struct LaunchConfig
{
    std::function<void(const Breakpoint& bp)> onBreakpointInstall;
    std::function<void(const Breakpoint& bp)> onBreakpointUninstall;
    std::function<void(const Breakpoint& bp)> onBreakpointHit;
    std::function<void(bool success)> onExit;
};

struct Target
{
    explicit Target(Runtime& parentRuntime);
    ~Target();

    // Setting breakpoints is a two step process. We add them to our Target. If they
    // involve a source that has already been loaded by the VM, we attempt to install that
    // breakpoint. Otherwise, it exists as a pending breakpoint until new sources are loaded.
    // We do this because clients may 1) configure breakpoints before launching executables
    // 2) we load sources dynamically with @require that a client may want to debug.
    // TODO: implement 2
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

    // For actively running scripts:
    bool launch(const std::string& sourcePath, const std::vector<std::string>& args, LaunchConfig config = {});
    bool continueProcess();

private:
    // targetMutex protects the entire Target, since Target can be accessed from the main thread
    // and the child runtime thread (i.e. in your debugbreak breakpoint callback).
    // This is ok because we are not looking for high performance but rather correctness.
    mutable std::mutex targetMutex;

    Runtime& parentRuntime;
    std::unique_ptr<Runtime> childRuntime;

    int currentBreakpointId = 0;
    bool paused = true;
    bool launched = false;
    std::unordered_map<int, Breakpoint> breakpoints; // breakpoint id -> breakpoint object (this is unordered_map to support erase)
    bool continueRequestedBp = false;
    std::optional<Breakpoint> bpHit;
    ResumeToken resumeToken;
    LaunchConfig launchConfig;

    Luau::DenseHashMap<std::string, std::shared_ptr<Ref>> loadedSources; // source path -> reference to chunk

    // thread for our running process
    lua_State* processThread = nullptr;

    // private methods are meant for internal calls, so these don't lock targetMutex
    std::optional<Breakpoint> getBreakpointBySourceLineHelper(std::string source, int line) const;
    std::optional<Breakpoint> getBreakpointByIdHelper(int breakpointId) const;

    bool installBreakpoint(lua_State* L, Breakpoint& bp);
    bool uninstallBreakpoint(lua_State* L, Breakpoint& bp);
    std::pair<std::vector<Breakpoint>, std::vector<Breakpoint>> modifyPendingBreakpoints(lua_State* L);

    void installBpHitCallback();
    void installExitCallback();
};
} // namespace debug
