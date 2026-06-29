#pragma once

#include "lute/runtime.h"

#include "Luau/DenseHash.h"

#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

namespace debug
{
enum class BreakpointStatus
{
    Pending,
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

struct Target
{
    explicit Target(Runtime& runtime, std::string sourcePath);

    // Setting breakpoints is a two step process. We add them to our Target. If they
    // involve a source that has already been loaded by the VM, we attempt to install that
    // breakpoint. Otherwise, it exists as a pending breakpoint until new sources are loaded.
    // We do this because clients may 1) configure breakpoints before launch executables
    // 2) we load sources dynamically with @require that a client may want to debug.
    // TODO: implement 2 and add some callback when breakpoints get installed
    Breakpoint addBreakpoint(std::string sourcePath, int line);
    std::vector<Breakpoint> getBreakpoints() const;
    std::optional<Breakpoint> getBreakpointById(int breakpointId) const;

    bool launch(const std::vector<std::string>& args);

private:
    Runtime& runtime;
    std::string sourcePath;

    int currentBreakpointId = 0;
    std::unordered_map<int, Breakpoint> breakpoints; // breakpoint id to breakpoint object (this is unordered_map to support erase)

    Luau::DenseHashMap<std::string, std::shared_ptr<Ref>> loadedSources; // source path -> reference to chunk

    bool installBreakpoint(lua_State* L, Breakpoint& bp);
    void installPendingBreakpoints(lua_State* L);
};

} // namespace debug
