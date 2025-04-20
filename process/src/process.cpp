#include "lute/process.h"
#include "lute/runtime.h"
#include <uv.h>
#include <string>
#include <vector>
#include <memory>
#include <functional>
#include <map>

#include "lua.h"
#include "lualib.h"

namespace process
{

struct ProcessHandle
{
    uv_process_t process;
    uv_pipe_t stdoutPipe;
    uv_pipe_t stderrPipe;
    uv_loop_t* loop = nullptr;
    std::string stdoutData;
    std::string stderrData;
    int64_t exitCode = -1;
    int termSignal = 0;
    bool completed = false;
    ResumeToken resumeToken;
    std::shared_ptr<ProcessHandle> self;
    std::atomic<int> pendingCloses{0};

    ~ProcessHandle() {}

    void closeHandles()
    {
        auto closeCb = [](uv_handle_t* handle)
        {
            ProcessHandle* ph = static_cast<ProcessHandle*>(handle->data);
            if (--ph->pendingCloses == 0)
            {
                ph->self.reset();
            }
        };

        if (stdoutPipe.loop && uv_is_active((uv_handle_t*)&stdoutPipe))
        {
            pendingCloses++;
            uv_read_stop((uv_stream_t*)&stdoutPipe);
            uv_close((uv_handle_t*)&stdoutPipe, closeCb);
        }
        if (stderrPipe.loop && uv_is_active((uv_handle_t*)&stderrPipe))
        {
            pendingCloses++;
            uv_read_stop((uv_stream_t*)&stderrPipe);
            uv_close((uv_handle_t*)&stderrPipe, closeCb);
        }
        if (process.loop)
        {
            pendingCloses++;
            uv_close((uv_handle_t*)&process, closeCb);
        }

        if (pendingCloses == 0)
        {
            self.reset();
        }
    }

    void triggerCompletion(bool success, const std::string& error_msg = "")
    {
        if (completed)
            return;
        completed = true;

        closeHandles();

        if (!resumeToken)
        {
            return;
        }

        if (success)
        {
            int64_t finalExitCode = exitCode;
            int finalTermSignal = termSignal;
            std::string finalStdout = stdoutData;
            std::string finalStderr = stderrData;
            std::string finalSignalStr = finalTermSignal ? std::to_string(finalTermSignal) : "";

            resumeToken->complete(
                [=](lua_State* L)
                {
                    lua_createtable(L, 0, 5); // ok, exitCode, stdout, stderr, signal

                    bool ok = (finalExitCode == 0 && finalTermSignal == 0);

                    lua_pushboolean(L, ok);
                    lua_setfield(L, -2, "ok");

                    lua_pushinteger(L, finalExitCode);
                    lua_setfield(L, -2, "exitcode");

                    lua_pushlstring(L, finalStdout.c_str(), finalStdout.length());
                    lua_setfield(L, -2, "stdout");

                    lua_pushlstring(L, finalStderr.c_str(), finalStderr.length());
                    lua_setfield(L, -2, "stderr");

                    if (!finalSignalStr.empty())
                    {
                        lua_pushstring(L, finalSignalStr.c_str());
                    }
                    else
                    {
                        lua_pushnil(L);
                    }
                    lua_setfield(L, -2, "signal");

                    return 1;
                }
            );
        }
        else
        {
            resumeToken->fail("Process error: " + error_msg);
        }

        resumeToken.reset();
    }
};

static void onProcessExit(uv_process_t* process, int64_t exitStatus, int termSignal)
{
    ProcessHandle* handle = static_cast<ProcessHandle*>(process->data);
    if (!handle || handle->completed)
        return;

    handle->exitCode = exitStatus;
    handle->termSignal = termSignal;

    handle->triggerCompletion(true);
}

static void onPipeRead(uv_stream_t* stream, ssize_t nread, const uv_buf_t* buf)
{
    ProcessHandle* handle = static_cast<ProcessHandle*>(stream->data);

    if (!handle || handle->completed)
    {
        if (buf->base)
            free(buf->base);
        return;
    }

    if (nread > 0)
    {
        std::string* targetBuffer = (stream == (uv_stream_t*)&handle->stdoutPipe) ? &handle->stdoutData : &handle->stderrData;
        targetBuffer->append(buf->base, nread);
    }
    else if (nread < 0)
    {
        if (nread != UV_EOF)
        {
            std::string errorDetails = (stream == (uv_stream_t*)&handle->stdoutPipe) ? "stdout" : "stderr";
            errorDetails += " read error: ";
            errorDetails += uv_strerror(nread);
            handle->triggerCompletion(false, errorDetails);
        }
    }

    if (buf->base)
    {
        free(buf->base);
    }
}

static void allocBuffer(uv_handle_t* handle, size_t suggestedSize, uv_buf_t* buf)
{
    buf->base = (char*)malloc(suggestedSize);
    buf->len = buf->base ? suggestedSize : 0;
    if (!buf->base)
    {
        fprintf(stderr, "Process pipe buffer allocation failed!\n");
    }
}

int create(lua_State* L)
{
    std::vector<std::string> args;
    if (lua_istable(L, 1))
    {
        int len = lua_objlen(L, 1);
        for (int i = 1; i <= len; i++)
        {
            lua_rawgeti(L, 1, i);
            args.push_back(lua_tostring(L, -1));
            lua_pop(L, 1);
        }
    }
    else
    {
        args.push_back(lua_tostring(L, 1));
    }

    if (args.empty() || args[0].empty())
    {
        luaL_error(L, "process.create requires a non-empty command");
        return 0;
    }

    bool useShell = false;
    std::string customShell;
    std::string cwd;
    std::map<std::string, std::string> env;

    if (lua_istable(L, 2))
    {
        lua_getfield(L, 2, "shell");
        if (lua_isboolean(L, -1))
        {
            useShell = lua_toboolean(L, -1);
        }
        else if (lua_isstring(L, -1))
        {
            customShell = lua_tostring(L, -1);
            useShell = true;
        }

        lua_pop(L, 1);

        lua_getfield(L, 2, "cwd");
        if (!lua_isnil(L, -1))
            cwd = lua_tostring(L, -1);

        lua_pop(L, 1);

        lua_getfield(L, 2, "env");
        if (lua_istable(L, -1))
        {
            lua_pushnil(L);
            while (lua_next(L, -2))
            {
                env[luaL_checkstring(L, -2)] = luaL_checkstring(L, -1);
                lua_pop(L, 1);
            }
        }
        lua_pop(L, 1);
    }

    if (useShell)
    {
        std::string commandStr = args[0];

        for (size_t i = 1; i < args.size(); ++i)
        {
            commandStr += " ";
            commandStr += args[i];
        }

#ifdef _WIN32
        const char* shellVar = "COMSPEC";
        const char* shellFallback = "cmd.exe";
        const char* shellArg = "/c";
#else
        const char* shellVar = "SHELL";
        const char* shellFallback = "/bin/sh";
        const char* shellArg = "-c";
#endif

        const char* shell = customShell.empty() ? nullptr : customShell.c_str();
        if (!shell)
        {
            char shellBuffer[1024];
            size_t shellSize = sizeof(shellBuffer);
            int result = uv_os_getenv(shellVar, shellBuffer, &shellSize);
            shell = result == 0 ? shellBuffer : shellFallback;
        }

        args = {shell, shellArg, commandStr};
    }

    auto handle = std::make_shared<ProcessHandle>();
    handle->loop = uv_default_loop();
    handle->self = handle;

    uv_process_options_t options = {};
    options.exit_cb = onProcessExit;
    options.file = args[0].c_str();

    std::vector<char*> processArgsPtr;
    for (const auto& arg : args)
    {
        processArgsPtr.push_back(const_cast<char*>(arg.c_str()));
    }
    processArgsPtr.push_back(nullptr);
    options.args = processArgsPtr.data();

    std::vector<std::string> envStrings;
    std::vector<char*> envPtr;
    if (!env.empty())
    {
        // Copy current environment into the new environment
        uv_env_item_t* currentEnvItems;
        int currentEnvCount;
        int err = uv_os_environ(&currentEnvItems, &currentEnvCount);
        if (err != 0)
        {
            luaL_error(L, "Failed to get current environment: %s", uv_strerror(err));
            return 0;
        }
        for (int i = 0; i < currentEnvCount; i++)
        {
            if (currentEnvItems[i].name && currentEnvItems[i].value && env.find(currentEnvItems[i].name) == env.end())
            {
                env[currentEnvItems[i].name] = currentEnvItems[i].value;
            }
        }
        // Turn the new environment into a char** array
        envStrings.reserve(env.size());
        envPtr.reserve(env.size() + 1);
        for (const auto& pair : env)
        {
            envStrings.push_back(pair.first + "=" + pair.second);
        }
        for (auto& str : envStrings)
        {
            envPtr.push_back(&str[0]);
        }
        envPtr.push_back(nullptr);
        options.env = envPtr.data();
    }

    if (!cwd.empty())
    {
        options.cwd = cwd.c_str();
    }

    uv_pipe_init(handle->loop, &handle->stdoutPipe, 0);
    uv_pipe_init(handle->loop, &handle->stderrPipe, 0);

    options.stdio_count = 3;
    uv_stdio_container_t stdio[3];
    stdio[0].flags = UV_INHERIT_FD;
    stdio[0].data.fd = 0; // Inherit stdin
    stdio[1].flags = static_cast<uv_stdio_flags>(UV_CREATE_PIPE | UV_WRITABLE_PIPE);
    stdio[1].data.stream = (uv_stream_t*)&handle->stdoutPipe;
    stdio[2].flags = static_cast<uv_stdio_flags>(UV_CREATE_PIPE | UV_WRITABLE_PIPE);
    stdio[2].data.stream = (uv_stream_t*)&handle->stderrPipe;
    options.stdio = stdio;

    handle->process.data = handle.get();
    handle->stdoutPipe.data = handle.get();
    handle->stderrPipe.data = handle.get();

    handle->resumeToken = getResumeToken(L);

    int spawnResult = uv_spawn(handle->loop, &handle->process, &options);

    if (spawnResult != 0)
    {
        if (handle->resumeToken)
        {
            handle->resumeToken->runtime->releasePendingToken();
            handle->resumeToken.reset();
        }
        handle->closeHandles();

        luaL_error(L, "Failed to spawn process: %s", uv_strerror(spawnResult));
        return 0;
    }

    uv_read_start((uv_stream_t*)&handle->stdoutPipe, allocBuffer, onPipeRead);
    uv_read_start((uv_stream_t*)&handle->stderrPipe, allocBuffer, onPipeRead);

    return lua_yield(L, 0);
}

static int envIndex(lua_State* L)
{
    const char* key = luaL_checkstring(L, 2);
    char value[1024];
    size_t size = sizeof(value);
    int err = uv_os_getenv(key, value, &size);

    if (err == UV_ENOBUFS)
    {
        char* buffer = (char*)malloc(size);
        err = uv_os_getenv(key, buffer, &size);
        if (err == 0)
        {
            lua_pushlstring(L, buffer, size);
            free(buffer);
            return 1;
        }
        free(buffer);
    }
    else if (err == UV_ENOENT)
    {
        lua_pushnil(L);
        return 1;
    }
    else if (err != 0)
    {
        luaL_error(L, "Failed to get environment variable: %s", uv_strerror(err));
        return 0;
    }

    lua_pushlstring(L, value, size);
    return 1;
}

static int envNewindex(lua_State* L)
{
    const char* key = luaL_checkstring(L, 2);
    int err;

    if (lua_isnil(L, 3))
    {
        err = uv_os_unsetenv(key);
    }
    else
    {
        const char* value = luaL_checkstring(L, 3);
        err = uv_os_setenv(key, value);
    }

    if (err != 0)
    {
        luaL_error(L, "Failed to set environment variable: %s", uv_strerror(err));
    }

    return 0;
}

struct EnvIter
{
    uv_env_item_t* items;
    int count;
    int index;
};

static int envIterNext(lua_State* L)
{
    EnvIter* iter = (EnvIter*)lua_touserdata(L, lua_upvalueindex(1));

    if (iter->index >= iter->count)
    {
        return 0;
    }

    lua_pushstring(L, iter->items[iter->index].name);
    lua_pushstring(L, iter->items[iter->index].value);
    iter->index++;
    return 2;
}

static int envIter(lua_State* L)
{
    uv_env_item_t* items;
    int count;
    int err = uv_os_environ(&items, &count);

    if (err != 0)
    {
        luaL_error(L, "Failed to get environment variables: %s", uv_strerror(err));
        return 0;
    }

    EnvIter* iter = (EnvIter*)lua_newuserdata(L, sizeof(EnvIter));
    iter->items = items;
    iter->count = count;
    iter->index = 0;

    luaL_getmetatable(L, "process.env.iterator");
    lua_setmetatable(L, -2);

    lua_pushvalue(L, -1);
    lua_pushcclosure(L, envIterNext, "envIterNext", 1);

    return 1;
}

static int envIterGc(lua_State* L)
{
    EnvIter* iter = (EnvIter*)lua_touserdata(L, 1);
    if (iter->items)
    {
        uv_os_free_environ(iter->items, iter->count);
        iter->items = nullptr;
        iter->count = 0;
    }
    return 0;
}

} // namespace process

static const luaL_Reg processEnvMeta[] =
    {{"__index", process::envIndex}, {"__newindex", process::envNewindex}, {"__iter", process::envIter}, {nullptr, nullptr}};

static const luaL_Reg processEnvIterMeta[] = {{"__gc", process::envIterGc}, {nullptr, nullptr}};

int luaopen_process(lua_State* L)
{
    luaL_register(L, "process", process::lib);
    return 1;
}

int luteopen_process(lua_State* L)
{
    lua_createtable(L, 0, std::size(process::lib));

    for (auto& [name, func] : process::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    luaL_newmetatable(L, "process.env.iterator");
    luaL_register(L, nullptr, processEnvIterMeta);
    lua_pop(L, 1);

    lua_newtable(L);
    luaL_newmetatable(L, "process.env");
    luaL_register(L, nullptr, processEnvMeta);
    lua_setmetatable(L, -2);
    lua_setfield(L, -2, "env");

    lua_setreadonly(L, -1, 1);

    return 1;
}
