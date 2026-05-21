#include "signal.h"

#include "lute/common.h"
#include "lute/runtime.h"
#include "lute/userdatas.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include <csignal>
#include <cstring>
#include <memory>
#include <string_view>
#include <unordered_set>

namespace process
{

// These signals cannot be caught or ignored at the OS level.
static const std::unordered_set<std::string_view> kUncatchableSignals = {"SIGKILL", "SIGSTOP"};

// These signals are generated synchronously by hardware exceptions, and thus cannot be safely handled from Luau code.
static const std::unordered_set<std::string_view> kHardwareSynchronousSignals = {"SIGBUS", "SIGFPE", "SIGSEGV", "SIGILL"};

// Returns the signal number for a name.
// Returns -1 for signals that are known but not available on this platform (no-op handle).
// Calls luaL_error for signals that are always invalid (uncatchable, reserved, or unsafe).
static int resolveSignal(lua_State* L, const char* name)
{
    // Uncatchable signals — always an error regardless of platform
    if (kUncatchableSignals.count(name))
        luaL_errorL(L, "%s cannot be handled", name);

    // Reserved by libuv for child process tracking
    if (strcmp(name, "SIGCHLD") == 0)
        luaL_errorL(L, "%s is reserved by the runtime", name);

    // Hardware synchronous signals — unsafe to handle from Luau
    if (kHardwareSynchronousSignals.count(name))
        luaL_errorL(L, "%s is a synchronous hardware signal and cannot be safely handled", name);

    // Always-available signals
    if (strcmp(name, "SIGINT") == 0)
        return SIGINT;
    if (strcmp(name, "SIGTERM") == 0)
        return SIGTERM;

    // Platform-conditional signals: return the signal number if available,
    // or -1 (no-op handle) if not defined on this platform.
    if (strcmp(name, "SIGHUP") == 0)
#ifdef SIGHUP
        return SIGHUP;
#else
        return -1;
#endif

    if (strcmp(name, "SIGQUIT") == 0)
#ifdef SIGQUIT
        return SIGQUIT;
#else
        return -1;
#endif

    if (strcmp(name, "SIGUSR1") == 0)
#ifdef SIGUSR1
        return SIGUSR1;
#else
        return -1;
#endif

    if (strcmp(name, "SIGUSR2") == 0)
#ifdef SIGUSR2
        return SIGUSR2;
#else
        return -1;
#endif

    if (strcmp(name, "SIGWINCH") == 0)
#ifdef SIGWINCH
        return SIGWINCH;
#else
        return -1;
#endif

    if (strcmp(name, "SIGPIPE") == 0)
#ifdef SIGPIPE
        return SIGPIPE;
#else
        return -1;
#endif

    if (strcmp(name, "SIGBREAK") == 0)
#ifdef SIGBREAK
        return SIGBREAK;
#else
        return -1;
#endif

    if (strcmp(name, "SIGALRM") == 0)
#ifdef SIGALRM
        return SIGALRM;
#else
        return -1;
#endif

    luaL_errorL(L, "unknown signal: %s", name);
}

struct SignalHandle
{
    SignalHandle(lua_State* L, int callbackIdx, int signum)
        : runtime(getRuntime(L))
        , callbackReference(std::make_shared<Ref>(L, callbackIdx))
    {
        if (signum < 0) // no-op: signal not available on this platform
            return;

        uvHandle = std::make_unique<uv_signal_t>();
        uvHandle->data = this;

        int err = uv_signal_init(runtime->getEventLoop(), uvHandle.get());
        if (err != 0)
        {
            uvHandle.reset();
            luaL_errorL(L, "uv_signal_init failed: %s", uv_strerror(err));
        }

        err = uv_signal_start(
            uvHandle.get(),
            [](uv_signal_t* h, int)
            {
                auto* self = static_cast<SignalHandle*>(h->data);
                self->runtime->scheduleLuauCallback(
                    self->callbackReference,
                    [](lua_State*) -> int
                    {
                        return 0;
                    }
                );
            },
            signum
        );
        if (err != 0)
        {
            uv_signal_stop(uvHandle.get());
            auto raw = uvHandle.release();
            uv_close((uv_handle_t*)raw, [](uv_handle_t* h) { delete (uv_signal_t*)h; });
            luaL_errorL(L, "uv_signal_start failed: %s", uv_strerror(err));
        }
    }

    void close()
    {
        if (isClosed)
            return;

        isClosed = true;

        if (!uvHandle) // no-op handle
            return;

        uv_signal_stop(uvHandle.get());
        callbackReference.reset();
        auto raw = uvHandle.release();
        uv_close(
            (uv_handle_t*)raw,
            [](uv_handle_t* h)
            {
                delete (uv_signal_t*)h;
            }
        );
    }

    ~SignalHandle()
    {
        close();
    }

    Runtime* runtime;
    std::shared_ptr<Ref> callbackReference;
    bool isClosed = false;
    std::unique_ptr<uv_signal_t> uvHandle; // null for no-op handles
};

static int closeSignalHandle(lua_State* L)
{
    auto* handle = static_cast<SignalHandle*>(lua_touserdatatagged(L, 1, kSignalHandleTag));
    if (!handle)
        luaL_errorL(L, "invalid signal handle");

    handle->close();
    return 0;
}

int signalFunc(lua_State* L)
{
    const char* name = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);

    int signum = resolveSignal(L, name);

    void* storage = lua_newuserdatataggedwithmetatable(L, sizeof(SignalHandle), kSignalHandleTag);
    new (storage) SignalHandle(L, 2, signum);

    return 1;
}

} // namespace process

void registerSignalHandle(lua_State* L)
{
    luaL_newmetatable(L, "SignalHandle");

    lua_pushcfunction(
        L,
        [](lua_State* L) -> int
        {
            const char* key = luaL_checkstring(L, 2);
            if (strcmp(key, "close") == 0)
            {
                lua_pushcfunction(L, process::closeSignalHandle, "SignalHandle.close");
                return 1;
            }
            return 0;
        },
        "SignalHandle.__index"
    );
    lua_setfield(L, -2, "__index");

    lua_pushstring(L, "SignalHandle");
    lua_setfield(L, -2, "__type");

    lua_setuserdatadtor(
        L,
        kSignalHandleTag,
        [](lua_State*, void* ud)
        {
            std::destroy_at(static_cast<process::SignalHandle*>(ud));
        }
    );

    lua_setuserdatametatable(L, kSignalHandleTag);
}
