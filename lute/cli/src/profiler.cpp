#include "lute/profiler.h"

#include "lute/reporter.h"

#include "lua.h"

#include <atomic>
#include <string>
#include <thread>
#include <vector>


struct FrameInfo
{
    std::string name;
    std::string file;
    int line;

    FrameInfo(const lua_Debug& dbg)
        : name(dbg.name ? dbg.name : "(anonymous)")
        , file(dbg.source ? &dbg.source[1] : "(unknown)") // TODO(Varun)replace with chunkname utils API
        , line(dbg.linedefined)
    {
    }

    bool operator==(const FrameInfo& other) const
    {
        return name == other.name && file == other.file && line == other.line;
    }
};

struct TraceEvent
{
    TraceEvent(char phase, const FrameInfo& fi, uint64_t timestamp)
        : phase(phase)
        , name(fi.name)
        , file(fi.file)
        , line(fi.line)
        , timestamp(timestamp)
    {
    }
    char phase; // 'B' for begin, 'E' for end
    std::string name;
    std::string file;
    int line;
    uint64_t timestamp; // Timestamp in microseconds
};

struct Profiler
{
    // static state
    lua_Callbacks* callbacks = nullptr;
    int frequency = ProfileOptions{}.frequency;
    std::thread thread;

    // variables for communication between loop and trigger
    std::atomic<bool> exit = false;
    std::atomic<uint64_t> pendingTicks = 0;

    // state for tracking stack changes (only accessed in trigger)
    std::vector<FrameInfo> previousStack;
    std::vector<TraceEvent> events;
    uint64_t currentTimestamp = 0;

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
    for (int level = 0; lua_getinfo(L, level, "sln", &dbg); ++level)
    {
        currentStack.emplace_back(dbg);
    }

    // Stacks are in reverse order, i.e
    // leaf ..... main, so we should walk backwards
    size_t commonDepth = 0;
    size_t iterPrev = gProfiler.previousStack.size();
    size_t iterCurr = currentStack.size();

    while (iterPrev > 0 && iterCurr > 0 && gProfiler.previousStack[iterPrev - 1] == currentStack[iterCurr - 1])
    {
        commonDepth++;
        iterPrev--;
        iterCurr--;
    }

    for (size_t i = 0; i < gProfiler.previousStack.size() - commonDepth; i++)
    {
        const FrameInfo& frame = gProfiler.previousStack.at(i);
        gProfiler.events.emplace_back('E', frame, gProfiler.currentTimestamp);
    }

    for (size_t i = currentStack.size() - commonDepth; i > 0; i--)
    {
        const FrameInfo& frame = currentStack.at(i - 1);
        gProfiler.events.emplace_back('B', frame, gProfiler.currentTimestamp);
    }

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

    // For any of the remaining frames on the stack, insert an artificial end(E) event.
    for (size_t i = 0; i < gProfiler.previousStack.size(); i++)
    {
        const FrameInfo& frame = gProfiler.previousStack.at(i);
        gProfiler.events.emplace_back('E', frame, gProfiler.currentTimestamp);
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
