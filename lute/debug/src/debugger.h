#pragma once

#include "lute/runtime.h"

#include <map>
#include <optional>
#include <string>
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
    Breakpoint(int id, std::string sourcePath, int line, BreakpointStatus status);
    bool operator==(const Breakpoint& other) const
    {
        return id == other.id;
    }
};

struct Target
{
    Target(std::string sourcePath, Runtime& runtime);

    // Setting breakpoints is a two step process. We add them to our Target. If they
    // involve a source that has already been loaded by the VM, we attempt to install that
    // breakpoint. Otherwise, it exists as a pending breakpoint until new sources are loaded.
    // We do this because clients may 1) configure breakpoints before launch executables
    // 2) we load sources dynamically with @require that a client may want to debug.
    // TODO: implement 2 and add some callback when breakpoints get installed
    Breakpoint addBreakpoint(std::string sourcePath, int line);
    std::vector<Breakpoint> getBreakpoints() const;
    std::optional<Breakpoint> getBreakpointById(int breakpointId) const;

    bool launch(std::vector<std::string> args);

private:
    std::string executablePath;
    Runtime& runtime;

    int currentBreakpointId = 0;
    std::vector<Breakpoint> pendingBreakpoints;
    std::vector<Breakpoint> installedBreakpoints;

    std::map<std::string, std::shared_ptr<Ref>> loadedSources;

    bool installBreakpoint(Breakpoint& bp, lua_State* L);
    void installPendingBreakpoints(lua_State* L);
};

} // namespace debug
