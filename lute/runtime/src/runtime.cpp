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

#include "Luau/Require.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

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
    activeTokens.store(0);

    // Set up the handle that we'll use to process continutations asynchronously
    // Whenever a libuv callback gets, we can signal via a resume token to continue
    // the original yielding thread
    int err = uv_async_init(uv_default_loop(), &asyncHandle,
        [](uv_async_t* handle) {
            auto* runtime = static_cast<Runtime*>(handle->data);
            runtime->processContinuations();
        }
    );

    if (err != 0)
    {
        fprintf(stderr, "Failed to initialize uv_async_t: %s\n", uv_strerror(err));
        asyncInitialized = false;
    }
    else
    {
        asyncHandle.data = this;
        asyncInitialized = true;
    }
}

Runtime::~Runtime()
{
    if (asyncInitialized)
    {
        uv_close((uv_handle_t*)&asyncHandle, nullptr);
        // Run the loop once to process the close callback
        uv_run(uv_default_loop(), UV_RUN_NOWAIT);
        // TODO: Do we need to set asyncInitialized to false?
    }
}

bool Runtime::hasWork()
{
    // Check if there's any work to do:
    // - Continuations queued (includes deferred tasks) - e.g. resuming luau threads
    // - Threads waiting to resume - e.g. http requests
    // - Active tokens (pending async operations)
    // Note: We don't use uv_loop_alive() because the async handle is always referenced
    return hasContinuations() || hasThreads() || activeTokens.load() != 0;
}

RuntimeStep Runtime::runOnce()
{
    // Just run the event loop once
    // processContinuations() is called automatically by uv_async callback
    uv_run(uv_default_loop(), UV_RUN_ONCE);

    // Return status based on whether we still have work
    if (hasWork())
        return StepSuccess{GL};

    return StepEmpty{};
}

bool Runtime::runToCompletion()
{
    // Simplified - just run event loop until no more work
    // Error handling happens inside processContinuations()

    // Process any threads that were added directly to runningThreads
    // before entering the event loop (e.g., the initial thread from runBytecode)
    processContinuations();

    while (hasWork())
    {
        uv_run(uv_default_loop(), UV_RUN_ONCE);
    }

    // Return false if any errors occurred during execution
    return !errorOccurred.load();
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

bool Runtime::hasContinuations()
{
    std::unique_lock lock(continuationMutex);
    return !continuations.empty();
}

bool Runtime::hasThreads()
{
    return !runningThreads.empty();
}

void Runtime::schedule(std::function<void()> f)
{
    {
        std::unique_lock lock(continuationMutex);
        continuations.push_back(std::move(f));
    }

    if (asyncInitialized)
    {
        uv_async_send(&asyncHandle);
    }
}

void Runtime::scheduleLuauError(std::shared_ptr<Ref> ref, std::string error)
{
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
    }

    // If you schedule a luau error, we send a notice to the event_loop to run the the callback
    // we registered
    if (asyncInitialized)
    {
        uv_async_send(&asyncHandle);
    }
}

void Runtime::scheduleLuauResume(std::shared_ptr<Ref> ref, std::function<int(lua_State*)> cont)
{
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
    }

    if (asyncInitialized)
    {
        uv_async_send(&asyncHandle);
    }
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

void Runtime::processContinuations()
{
    // Process continuations AND resume threads on the uv event loop
    // This is called by the uv_async callback
    std::vector<std::function<void()>> copy;

    {
        std::unique_lock lock(continuationMutex);
        copy = std::move(continuations);
        continuations.clear();
    }

    // Execute all continuations (these populate runningThreads)
    for (auto&& continuation : copy)
    {
        continuation();
    }

    // Now resume all pending Lua threads
    // This happens on the event loop thread, not the separate thread
    while (!runningThreads.empty())
    {
        auto next = std::move(runningThreads.front());
        runningThreads.erase(runningThreads.begin());

        next.ref->push(GL);
        lua_State* L = lua_tothread(GL, -1);

        if (L == nullptr)
        {
            fprintf(stderr, "Cannot resume a non-thread reference\n");
            lua_pop(GL, 1);
            continue;
        }

        lua_pop(GL, 1);

        int status = LUA_OK;

        if (!next.success)
            status = lua_resumeerror(L, nullptr);
        else
            status = lua_resume(L, nullptr, next.argumentCount);

        if (status != LUA_OK && status != LUA_YIELD)
        {
            reportError(L);
            errorOccurred.store(true);
        }

        if (next.cont)
            next.cont();
    }
}

Runtime* getRuntime(lua_State* L)
{
    return static_cast<Runtime*>(lua_getthreaddata(lua_mainthread(L)));
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

lua_State* setupState(Runtime& runtime, std::function<void(lua_State*)> doBeforeSandbox)
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
