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

struct Process;

struct Target
{
    explicit Target(Runtime& parentRuntime, std::string sourcePath);

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

    std::shared_ptr<Process> launch(
        const std::vector<std::string>& args,
        std::function<void(const Breakpoint& bp)> onBreakpointInstall = {},
        std::function<void(const Breakpoint& bp)> onBreakpointUninstall = {},
        std::function<void(Process& process, const Breakpoint& bp)> onBreakpointHit = {}
    );

private:
    Runtime& parentRuntime;
    std::shared_ptr<Runtime> childRuntime;
    std::string sourcePath;

    int currentBreakpointId = 0;
    std::unordered_map<int, Breakpoint> breakpoints; // breakpoint id -> breakpoint object (this is unordered_map to support erase)
    mutable std::mutex breakpointsMutex;

    std::function<void(const Breakpoint& bp)> onBreakpointInstall;
    std::function<void(const Breakpoint& bp)> onBreakpointUninstall;

    Luau::DenseHashMap<std::string, std::shared_ptr<Ref>> loadedSources; // source path -> reference to chunk

    bool installBreakpoint(lua_State* L, Breakpoint& bp);
    void installPendingBreakpoints(lua_State* L);
};

struct Process
{
    explicit Process(Runtime& runtime, Target& parentTarget, std::function<void(Process& process, const Breakpoint& bp)> onBreakpointHit);
    Target& getTarget();
    bool continueProcess();

private:
    Runtime& runtime;
    Target& parentTarget;
    ResumeToken resumeToken;

    std::function<void(Process& process, const Breakpoint& bp)> onBreakpointHit;
    void installBpHitCallback();
};
} // namespace debug
