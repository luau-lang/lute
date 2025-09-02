#include "lute/runtime.h"

#include "lute/crypto.h"
#include "lute/fs.h"
#include "lute/luau.h"
#include "lute/net.h"
#include "lute/process.h"
#include "lute/system.h"
#include "lute/task.h"
#include "lute/vm.h"
#include "lute/time.h"
#include "lute/exception.h"

#include "Luau/Require.h"

#include "lua.h"
#include "lualib.h"
#include "uv.h"

#include <cstdio>
#include <memory>
#include <mutex>
#include <string>
#include <assert.h>

static void lua_close_checked(lua_State* L)
{
    if (L)
        lua_close(L);
}

Runtime::Runtime()
    : globalState(nullptr, lua_close_checked)
    , dataCopy(nullptr, lua_close_checked)
{
    stop.store(false);
    activeTokens.store(0);
}

Runtime::~Runtime()
{
    {
        std::unique_lock lock(continuationMutex);

        stop.store(true);

        runLoopCv.notify_one();
    }

    if (runLoopThread.joinable())
        runLoopThread.join();
}

bool Runtime::hasWork()
{
    return hasThreads() || activeTokens.load() != 0 || hasContinuations() || hasTasks();
}

RuntimeStep Runtime::runTaskExecutor()
{
    std::unique_lock<std::mutex> lock{continuationMutex};

    if (scheduledTasks.empty())
    {
        return StepEmpty{};
    }

    auto task = std::move(scheduledTasks.back());
    scheduledTasks.pop_back();

    lock.unlock();

    lua_State* L = task->getThread();
    int nargs = task->resume();
    int status = lua_resume(L, nullptr, nargs);

    if (status == LUA_YIELD)
    {
        return StepSuccess{L};
    }

    if (status != LUA_OK)
    {
        return StepErr{L};
    }

    return StepSuccess{L};
}

RuntimeStep Runtime::runOnce()
{
    uv_run(uv_default_loop(), UV_RUN_DEFAULT);

    // Complete all C++ continuations
    std::vector<std::function<void()>> copy;

    {
        std::unique_lock lock(continuationMutex);
        copy = std::move(continuations);
        continuations.clear();
    }

    for (auto&& continuation : copy)
        continuation();

    if (runningThreads.empty())
        return StepEmpty{};

    auto next = std::move(runningThreads.front());
    runningThreads.erase(runningThreads.begin());

    next.ref->push(GL);
    lua_State* L = lua_tothread(GL, -1);

    if (L == nullptr)
    {
        fprintf(stderr, "Cannot resume a non-thread reference");
        return StepErr{L};
    }

    // We still have 'next' on stack to hold on to thread we are about to run
    lua_pop(GL, 1);

    int status = LUA_OK;

    if (!next.success)
        status = lua_resumeerror(L, nullptr);
    else
        status = lua_resume(L, nullptr, next.argumentCount);

    if (status == LUA_YIELD)
    {
        return StepSuccess{L};
    }

    if (status != LUA_OK)
    {
        return StepErr{L};
    };

    if (next.cont)
        next.cont();

    return StepSuccess{L};
}

bool Runtime::runToCompletion()
{
    while (hasWork())
    {
        RuntimeStep step = StepEmpty{};
        bool hasExecuted = false;

        if (hasThreads() || hasContinuations() || activeTokens.load() > 0)
        {
            hasExecuted = true;
            step = runOnce();
        }

        if (Luau::get_if<StepSuccess>(&step) || Luau::get_if<StepEmpty>(&step))
        {
            if (!hasExecuted)
            {
                uv_run(uv_default_loop(), UV_RUN_DEFAULT);
            }
            
            step = runTaskExecutor();
        }

        if (auto err = Luau::get_if<StepErr>(&step))
        {
            if (err->L == nullptr)
            {
                fprintf(stderr, "lua_State* L is nullptr");
                return false;
            }

            reportError(err->L);

            // ensure we exit the process with error code properly
            if (!hasWork())
                return false;
        }
        else
        {
            continue;
        }
    };

    return true;
}

void Runtime::reportError(lua_State* L)
{
    std::string error;

    if (const char* str = lua_tostring(L, -1))
        error = str;

    error += "\nstacktrace:\n";
    error += lua_debugtrace(L);

    fprintf(stderr, "%s", error.c_str());
}

void Runtime::runContinuously()
{
    // TODO: another place for libuv
    runLoopThread = std::thread(
        [this]
        {
            while (!stop)
            {
                // Block to wait on event
                {
                    std::unique_lock lock(continuationMutex);

                    runLoopCv.wait(
                        lock,
                        [this]
                        {
                            return !continuations.empty() || stop;
                        }
                    );
                }

                runToCompletion();
            }
        }
    );
}

bool Runtime::hasContinuations()
{
    std::unique_lock lock(continuationMutex);
    return !continuations.empty();
}

bool Runtime::hasThreads()
{
    return !runningThreads.empty();
}

bool Runtime::hasTasks()
{
    std::unique_lock lock(continuationMutex);
    return !scheduledTasks.empty() || !yieldedTasks.empty();
}

void Runtime::schedule(std::function<void()> f)
{
    std::unique_lock lock(continuationMutex);

    continuations.push_back(std::move(f));

    runLoopCv.notify_one();
}

void Runtime::scheduleLuauError(std::shared_ptr<Ref> ref, std::string error)
{
    std::unique_lock lock(continuationMutex);

    continuations.push_back(
        [this, ref, error = std::move(error)]() mutable
        {
            ref->push(GL);
            lua_State* L = lua_tothread(GL, -1);
            lua_pop(GL, 1);

            lua_pushlstring(L, error.data(), error.size());
            runningThreads.push_back({false, ref, lua_gettop(L)});
        }
    );

    runLoopCv.notify_one();
}

void Runtime::scheduleLuauResume(std::shared_ptr<Ref> ref, std::function<int(lua_State*)> cont)
{
    std::unique_lock lock(continuationMutex);

    continuations.push_back(
        [this, ref, cont = std::move(cont)]() mutable
        {
            ref->push(GL);
            lua_State* L = lua_tothread(GL, -1);
            lua_pop(GL, 1);

            int results = cont(L);
            runningThreads.push_back({true, ref, results});
        }
    );

    runLoopCv.notify_one();
}

void Runtime::runInWorkQueue(std::function<void()> f)
{
    auto loop = uv_default_loop();

    uv_work_t* work = new uv_work_t();
    work->data = new decltype(f)(std::move(f));

    uv_queue_work(
        loop,
        work,
        [](uv_work_t* req)
        {
            auto task = *(decltype(f)*)req->data;

            task();
        },
        [](uv_work_t* req, int status)
        {
            delete (decltype(f)*)req->data;
            delete req;
        }
    );
}

void Runtime::addPendingToken()
{
    activeTokens.fetch_add(1);
}

void Runtime::releasePendingToken()
{
    [[maybe_unused]] int before = activeTokens.fetch_sub(1);
    assert(before > 0);
}

lua_State* Runtime::newThread()
{
    lua_State* L = lua_newthread(GL);

    return L;
}

Task* Runtime::addTask(std::unique_ptr<Task> task)
{
    std::unique_lock<std::mutex> lock(continuationMutex);

    yieldedTasks.push_back(std::move(task));
    auto& taskRef = yieldedTasks.back();

    lock.unlock(); // we need to unlock to allow for immediately scheduling tasks

    taskRef->start();

    return taskRef.get();
}

void Runtime::scheduleTask(Task* task)
{
    std::lock_guard<std::mutex> lock(continuationMutex);

    auto it = std::find_if(
        yieldedTasks.begin(),
        yieldedTasks.end(),
        [task](const auto& t)
        {
            return t.get() == task;
        }
    );

    if (it != yieldedTasks.end())
    {
        scheduledTasks.push_back(std::move(*it));
        yieldedTasks.erase(it);
        return;
    }

    throw LuteException("Attempted to schedule a task that does not exist");
}

void Runtime::cancelTask(Task* task)
{
    std::lock_guard<std::mutex> lock(continuationMutex);

    auto it = std::find_if(
        yieldedTasks.begin(),
        yieldedTasks.end(),
        [task](const auto& t)
        {
            return t.get() == task;
        }
    );

    if (it != yieldedTasks.end())
    {
        yieldedTasks.erase(it);
        return;
    }

    throw LuteException("Attempted to cancel a task that does not exist");
}

Runtime* getRuntime(lua_State* L)
{
    return reinterpret_cast<Runtime*>(lua_getthreaddata(lua_mainthread(L)));
}

void ResumeTokenData::fail(std::string error)
{
    assert(!completed);
    completed = true;

    runtime->scheduleLuauError(ref, std::move(error));
    runtime->releasePendingToken();
}

void ResumeTokenData::complete(std::function<int(lua_State*)> cont)
{
    assert(!completed);
    completed = true;

    runtime->scheduleLuauResume(ref, std::move(cont));
    runtime->releasePendingToken();
}

ResumeToken getResumeToken(lua_State* L)
{
    ResumeToken token = std::make_shared<ResumeTokenData>();

    token->runtime = getRuntime(L);
    token->ref = getRefForThread(L);

    token->runtime->addPendingToken();

    return token;
}

static void luteopen_libs(lua_State* L)
{
    std::vector<std::pair<const char*, lua_CFunction>> libs = {{
        {"@lute/crypto", luteopen_crypto},
        {"@lute/fs", luteopen_fs},
        {"@lute/luau", luteopen_luau},
        {"@lute/net", luteopen_net},
        {"@lute/process", luteopen_process},
        {"@lute/task", luteopen_task},
        {"@lute/vm", luteopen_vm},
        {"@lute/system", luteopen_system},
        {"@lute/time", luteopen_time},
    }};

    for (const auto& [name, func] : libs)
    {
        lua_pushcfunction(L, luarequire_registermodule, nullptr);
        lua_pushstring(L, name);
        func(L);
        lua_call(L, 2, 0);
    }
}

lua_State* setupState(Runtime& runtime, void (*doBeforeSandbox)(lua_State*))
{
    // Separate VM for data copies
    runtime.dataCopy.reset(luaL_newstate());

    runtime.globalState.reset(luaL_newstate());

    lua_State* L = runtime.globalState.get();

    runtime.GL = L;

    lua_setthreaddata(L, &runtime);

    // register the builtin tables
    luaL_openlibs(L);

    luteopen_libs(L);

    lua_pushnil(L);
    lua_setglobal(L, "setfenv");

    lua_pushnil(L);
    lua_setglobal(L, "getfenv");

    if (doBeforeSandbox)
        doBeforeSandbox(L);

    luaL_sandbox(L);

    return L;
}

void Task::schedule()
{
    runtime->scheduleTask(this);
}

void Task::cancel()
{
    runtime->cancelTask(this);
}