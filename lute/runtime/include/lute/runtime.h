#pragma once

#include "lute/ref.h"
#include "lute/reporter.h"

#include "Luau/Variant.h"
#include "Luau/VecDeque.h"

#include "uv.h"

#include <atomic>
#include <condition_variable>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

struct lua_State;

namespace Luau
{
struct CompileOptions;
}

struct ThreadToContinue
{
    bool success = false;
    std::shared_ptr<Ref> ref;
    int argumentCount = 0;
    std::function<void()> cont;
};

// Optional completion hook for threads that need native follow-up work once
// they finish or error after one or more yields.
struct ThreadCompletionHandler
{
    std::function<void(lua_State* L, int status)> onFinish;
};

struct StepErr
{
    lua_State* L;
};

struct StepSuccess
{
    lua_State* L;
};

struct StepEmpty
{
};

using RuntimeStep = Luau::Variant<StepSuccess, StepErr, StepEmpty>;

struct Runtime
{
    Runtime(LuteReporter& reporter);
    ~Runtime();

    bool runToCompletion();
    RuntimeStep runOnce();

    // For child runtimes, run a thread waiting for work
    void runContinuously();

    // Reports an error for a specified lua state.
    void reportError(lua_State* L);

    bool hasWork();
    bool hasContinuations();
    bool hasThreads();

    void schedule(std::function<void()> f);

    // Resume thread with the specified error
    void scheduleLuauError(std::shared_ptr<Ref> ref, std::string error);

    // Resume thread with the results computed by the continuation
    void scheduleLuauResume(std::shared_ptr<Ref> ref, std::function<int(lua_State*)> cont);

    // Invoke a Luau callback function on a fresh thread.
    // argPusher should push arguments onto the stack and return the count.
    void scheduleLuauCallback(std::shared_ptr<Ref> callbackRef, std::function<int(lua_State*)> argPusher);

    // Attach native follow-up work to a specific Luau thread. The hook will run
    // once that thread eventually returns or errors after any number of yields.
    void addThreadCompletionHandler(lua_State* L, ThreadCompletionHandler completion);

    // Run 'f' in a libuv work queue
    void runInWorkQueue(std::function<void()> f);

    void addPendingToken();
    void releasePendingToken();

    uv_loop_t* getEventLoop();

    // Load and run bytecode.
    // If provided, onLoaded is called after bytecode is loaded
    // with the loaded function at the top of the stack.
    bool runBytecode(
        const std::string& bytecode,
        const std::string& chunkname,
        int argc = 0,
        char** argv = nullptr,
        std::function<void(lua_State*)> onLoaded = nullptr
    );

    // Compile Luau source and run it.
    bool runSource(
        const std::string& source,
        const Luau::CompileOptions& compileOptions,
        const std::string& chunkname = "=stdin",
        int argc = 0,
        char** argv = nullptr
    );

    LuteReporter& reporter;

    // VM for this runtime
    std::unique_ptr<lua_State, void (*)(lua_State*)> globalState;

    // Shorthand for global state
    lua_State* GL = nullptr;

    std::mutex dataCopyMutex;
    std::unique_ptr<lua_State, void (*)(lua_State*)> dataCopy;

    Luau::VecDeque<ThreadToContinue> runningThreads;

    // CLI arguments passed after the script filename
    std::vector<std::string> args;

    // Factory function for creating an identical require context in child
    // Runtimes. Set during parent Runtime's setup.
    std::function<void*(lua_State*)> requireContextFactory;

private:
    bool runThreadCompletionHandler(lua_State* L, int status);
    void clearThreadCompletionHandler(lua_State* L);

    std::mutex continuationMutex;
    std::vector<std::function<void()>> continuations;
    std::unordered_map<lua_State*, ThreadCompletionHandler> threadCompletionHandlers;

    std::atomic<bool> stop;
    std::condition_variable runLoopCv;
    uv_thread_t runLoopThread = {};
    bool runLoopThreadStarted = false;

    std::atomic<int> activeTokens;
    uv_loop_t eventLoop;
};

Runtime* getRuntime(lua_State* L);
uv_loop_t* getRuntimeLoop(lua_State* L);

struct ResumeTokenData;
using ResumeToken = std::shared_ptr<ResumeTokenData>;

struct ResumeTokenData
{
    static ResumeToken get(lua_State* L);

    void fail(std::string error);
    void complete(std::function<int(lua_State*)> cont);

    Runtime* runtime = nullptr;
    std::shared_ptr<Ref> ref;
    bool completed = false;
};

ResumeToken getResumeToken(lua_State* L);

lua_State* setupState(Runtime& runtime, std::function<void(lua_State*)> doBeforeSandbox);
