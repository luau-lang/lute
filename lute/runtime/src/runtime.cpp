#include "lute/runtime.h"

#include "lute/common.h"
#include "lute/ref.h"

#include "Luau/Compiler.h"

#include "lua.h"
#include "luacode.h"
#include "lualib.h"

#include "uv.h"

#include <assert.h>
#include <string>

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

    if (uv_loop_init(&eventLoop) < 0)
    {
        LUTE_ASSERT("Couldn't initialize runtime event loop");
    }
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
    // At this point, Runtime::hasWork will have returned false (i.e uv_loop_alive is false)
    // This means there are no outstanding handles, or file descriptors or work, to do, and we can exit
    uv_loop_close(&eventLoop);
}

bool Runtime::hasWork()
{
    // TODO: activeTokens and uv_loop_alive have a decent amount of overlap.
    // Unfortunately, we do currently have some places where we add/release
    // tokens that don't correspond to libuv activity, so for now we keep both.
    // uv_ref/unref could be used to patch tokens into the libuv loop itself.
    return hasContinuations() || hasThreads() || activeTokens.load() != 0 || uv_loop_alive(getEventLoop());
}

RuntimeStep Runtime::runOnce()
{
    uv_run_mode mode = (hasContinuations() || hasThreads()) ? UV_RUN_NOWAIT : UV_RUN_ONCE;
    uv_run(getEventLoop(), mode);

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
    runningThreads.pop_front();

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

    // It's possible for a spawned task to be killed by a coroutine.close()
    // before it gets processed in the runningThreads queue. This leads to situations where a thread was scheduled to resume
    // but has already been killed.

    // One example:
    // 1) Main thread executes task.defer on a coroutine.create thread
    // 2) Code is queued up on the thread
    // 3) coroutine.cancel is invoked
    // 4) runtime evaluates callbacks
    // 5) runtime evaluates running threads <- UH OH, found a thread that was scheduled to resume but has already been killed
    // 6) We can just step over it, because
    // a) if it scheduled a resume, the corresponding pending token will have been cleared
    // b) the corresponding ref for the lua state will be freed at the end of Runtime::runOnce()
    int co_status = lua_costatus(GL, L);
    if (co_status == LUA_COFIN)
    {
        return StepSuccess{L};
    }

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
        auto step = runOnce();

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
    auto loop = getEventLoop();
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

uv_loop_t* Runtime::getEventLoop()
{
    return &eventLoop;
}

Runtime* getRuntime(lua_State* L)
{
    return static_cast<Runtime*>(lua_getthreaddata(lua_mainthread(L)));
}

uv_loop_t* getRuntimeLoop(lua_State* L)
{
    return getRuntime(L)->getEventLoop();
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

bool Runtime::runBytecode(const std::string& bytecode, const std::string& chunkname, int argc, char** argv, std::function<void(lua_State*)> onLoaded)
{
    lua_State* L = lua_newthread(GL);

    luaL_sandboxthread(L);

    if (luau_load(L, chunkname.c_str(), bytecode.data(), bytecode.size(), 0) != 0)
    {
        reportError(L);
        lua_pop(GL, 1);
        return false;
    }

    if (onLoaded)
        onLoaded(L);

    if (argc > 0 && argv != nullptr)
    {
        if (!lua_checkstack(L, argc))
        {
            fprintf(stderr, "Failed to pass arguments to Luau\n");
            lua_pop(GL, 1);
            return false;
        }

        for (int i = 0; i < argc; ++i)
            lua_pushstring(L, argv[i]);
    }

    args.clear();
    for (int i = 0; i < argc; ++i)
        args.emplace_back(argv[i]);

    runningThreads.push_back({true, getRefForThread(L), argc});

    lua_pop(GL, 1);

    return runToCompletion();
}

bool Runtime::runSource(const std::string& source, const Luau::CompileOptions& compileOptions, const std::string& chunkname, int argc, char** argv)
{
    std::string bytecode = Luau::compile(source, compileOptions);
    return runBytecode(bytecode, chunkname, argc, argv);
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

    lua_pushnil(L);
    lua_setglobal(L, "setfenv");

    lua_pushnil(L);
    lua_setglobal(L, "getfenv");

    if (doBeforeSandbox)
        doBeforeSandbox(L);

    luaL_sandbox(L);

    return L;
}
