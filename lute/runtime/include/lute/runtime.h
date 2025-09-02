#pragma once

#include "Luau/Common.h"
#include "Luau/Variant.h"
#include "lute/exception.h"
#include "lute/ref.h"

#include <atomic>
#include <condition_variable>
#include <functional>
#include <list>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

struct lua_State;
class Task;

struct ThreadToContinue
{
    bool success = false;
    std::shared_ptr<Ref> ref;
    int argumentCount = 0;
    std::function<void()> cont;
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
    Runtime();
    ~Runtime();

    bool runToCompletion();

    RuntimeStep runTaskExecutor();
    RuntimeStep runOnce();

    // For child runtimes, run a thread waiting for work
    void runContinuously();

    // Reports an error for a specified lua state.
    void reportError(lua_State* L);

    bool hasWork();
    bool hasContinuations();
    bool hasThreads();
    bool hasTasks();

    void schedule(std::function<void()> f);

    // Resume thread with the specified error
    void scheduleLuauError(std::shared_ptr<Ref> ref, std::string error);

    // Resume thread with the results computed by the continuation
    void scheduleLuauResume(std::shared_ptr<Ref> ref, std::function<int(lua_State*)> cont);

    // Run 'f' in a libuv work queue
    void runInWorkQueue(std::function<void()> f);

    void addPendingToken();
    void releasePendingToken();

    // Creates a new thread, ready for use
    lua_State* newThread();

    // Adds a task to the list of yielded tasks, calling its start method
    Task* addTask(std::unique_ptr<Task> task);

    // Moves a yielded task to the list of tasks scheduled for resumption
    void scheduleTask(Task* task);

    // Cancels a task, removing it from the list of tasks
    void cancelTask(Task* task);

    // VM for this runtime
    std::unique_ptr<lua_State, void (*)(lua_State*)> globalState;

    // Shorthand for global state
    lua_State* GL = nullptr;

    std::mutex dataCopyMutex;
    std::unique_ptr<lua_State, void (*)(lua_State*)> dataCopy;

    std::vector<ThreadToContinue> runningThreads;

private:
    std::mutex continuationMutex;
    std::vector<std::function<void()>> continuations;

    std::vector<std::unique_ptr<Task>> scheduledTasks;
    std::list<std::unique_ptr<Task>> yieldedTasks;

    // TODO: can this be handled by libuv?
    std::atomic<bool> stop;
    std::condition_variable runLoopCv;
    std::thread runLoopThread;

    std::atomic<int> activeTokens;
};

Runtime* getRuntime(lua_State* L);

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

lua_State* setupState(Runtime& runtime, void (*doBeforeSandbox)(lua_State*));

// handling of runtime tasks

class Task
{
public:
    Task(Runtime* runtime, lua_State* L)
        : runtime{runtime}
        , L{L}
    {
    }

    virtual ~Task() = default;

    // Starts the task, this should be used in particular to start libuv operations or other async tasks
    virtual void start() = 0;

    // Called in order to resume the associated Luau thread with args provided here
    virtual int resume() = 0;

    // Schedules this task for resumption on the Runtime
    void schedule();

    // Cancels this task
    void cancel();

    lua_State* getThread() const
    {
        return L;
    }

    Runtime* getRuntime() const
    {
        return runtime;
    }

private:
    Runtime* runtime;
    lua_State* L;
};