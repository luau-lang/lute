#include "lute/profiler.h"

#include "lute/reporter.h"

#include "Luau/Common.h"
#include "Luau/FileUtils.h"

#include "lua.h"

#include <atomic>
#include <cstdio>
#include <string>
#include <thread>
#include <vector>


struct FrameInfo
{
    std::string name;
    std::string file;
    int line;

    bool operator==(const FrameInfo& other) const
    {
        return name == other.name && file == other.file && line == other.line;
    }
};

struct TraceEvent
{
    char phase; // 'B' for begin, 'E' for end
    std::string name;
    std::string file;
    int line;
    uint64_t timestamp;
};

struct Profiler
{
    // static state
    lua_Callbacks* callbacks = nullptr;
    int frequency = 100000;
    std::thread thread;

    // variables for communication between loop and trigger
    std::atomic<bool> exit = false;
    std::atomic<uint64_t> pendingTicks = 0;

    // state for tracking stack changes (only accessed in trigger)
    std::vector<FrameInfo> previousStack;
    std::vector<TraceEvent> events;
    uint64_t currentTimestamp = 0; // running timestamp in microseconds

} gProfiler;

static void profilerTrigger(lua_State* L, int gc)
{
    uint64_t ticks = gProfiler.pendingTicks.exchange(0);
    if (ticks == 0)
    {
        gProfiler.callbacks->interrupt = nullptr;
        return;
    }

    std::vector<FrameInfo> currentStack;
    lua_Debug dbg;
    int level = 0;
    while (lua_getinfo(L, level, "sln", &dbg))
    {
        FrameInfo frame;
        frame.name = dbg.name ? dbg.name : "(anonymous)";
        frame.file = dbg.short_src ? dbg.short_src : "(unknown)";
        frame.line = dbg.linedefined;
        currentStack.push_back(frame);
        level++;
    }

    // lua_getinfo level walks the stack from the current call(top) to the first call(bottom) - we'll have to reverse this here
    std::reverse(currentStack.begin(), currentStack.end());

    // Find where stacks diverge
    size_t commonDepth = 0;
    while (commonDepth < gProfiler.previousStack.size() && commonDepth < currentStack.size() &&
           gProfiler.previousStack[commonDepth] == currentStack[commonDepth])
    {
        commonDepth++;
    }

    // This code just implements coalescing - if the previous stack differs from the current stack like so
    //  prev top ..|.... bottom
    //  prev top ..|......bottom'
    // Then for everything in the previous stack, starting from the bottom in reverse
    // we should emit end events,
    // and for everything in the new stack, we should emit begin events, moving forward
    // so that all the nesting works correctly.
    for (size_t i = gProfiler.previousStack.size(); i > commonDepth; i--)
    {
        const FrameInfo& frame = gProfiler.previousStack[i - 1];
        TraceEvent evt;
        evt.phase = 'E';
        evt.name = frame.name;
        evt.file = frame.file;
        evt.line = frame.line;
        evt.timestamp = gProfiler.currentTimestamp;
        gProfiler.events.push_back(evt);
    }

    for (size_t i = commonDepth; i < currentStack.size(); i++)
    {
        const FrameInfo& frame = currentStack[i];
        TraceEvent evt;
        evt.phase = 'B';
        evt.name = frame.name;
        evt.file = frame.file;
        evt.line = frame.line;
        evt.timestamp = gProfiler.currentTimestamp;
        gProfiler.events.push_back(evt);
    }

    // Advance timestamp by elapsed ticks
    gProfiler.currentTimestamp += ticks;
    gProfiler.previousStack = std::move(currentStack);
    gProfiler.callbacks->interrupt = nullptr;
}

static void profilerLoop()
{
    double last = lua_clock();

    while (!gProfiler.exit)
    {
        double now = lua_clock();

        if (now - last >= 1.0 / double(gProfiler.frequency))
        {
            uint64_t ticks = uint64_t((now - last) * 1e6);

            gProfiler.pendingTicks += ticks;
            gProfiler.callbacks->interrupt = profilerTrigger;

            last += ticks * 1e-6;
        }
        else
        {
            std::this_thread::yield();
        }
    }
}

void profilerStart(lua_State* L, int frequency)
{
    gProfiler.frequency = frequency;
    gProfiler.callbacks = lua_callbacks(L);
    gProfiler.previousStack.clear();
    gProfiler.events.clear();
    gProfiler.currentTimestamp = 0;
    gProfiler.pendingTicks = 0;

    gProfiler.exit = false;
    gProfiler.thread = std::thread(profilerLoop);
}

void profilerStop()
{
    gProfiler.exit = true;
    gProfiler.thread.join();

    // Emit 'E' events for any remaining frames on the stack
    for (size_t i = gProfiler.previousStack.size(); i > 0; i--)
    {
        const FrameInfo& frame = gProfiler.previousStack[i - 1];
        TraceEvent evt;
        evt.phase = 'E';
        evt.name = frame.name;
        evt.file = frame.file;
        evt.line = frame.line;
        evt.timestamp = gProfiler.currentTimestamp;
        gProfiler.events.push_back(evt);
    }
    gProfiler.previousStack.clear();
}

void profilerDump(const char* path, LuteReporter& reporter)
{
    FILE* out = fopen(path, "w");
    if (!out)
    {
        reporter.formatError("Failed to open profile output file: %s", path);
        return;
    }

    fprintf(out, "{\"traceEvents\":[\n");

    for (size_t i = 0; i < gProfiler.events.size(); i++)
    {
        const TraceEvent& evt = gProfiler.events[i];

        if (i > 0)
            fprintf(out, ",\n");

        fprintf(out, "{\"ph\":\"%c\",", evt.phase);
        fprintf(out, "\"name\":\"%s\",", evt.name.c_str());
        fprintf(out, "\"cat\":\"function\",");
        fprintf(out, "\"pid\":1,\"tid\":1,");
        fprintf(out, "\"ts\":%llu", static_cast<unsigned long long>(evt.timestamp));
        fprintf(out, ",\"args\":{\"file\":\"%s\",\"line\":%d}}", evt.file.c_str(), evt.line);
    }

    fprintf(out, "\n]}\n");
    fclose(out);

    reporter.reportOutput("Profile written to " + std::string(path) + " (" + std::to_string(gProfiler.events.size()) + " events)");
}
