#include "lute/process.h"

#include "lute/common.h"
#include "lute/runtime.h"
#include "lute/uvutils.h"

#include "Luau/Common.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include <climits> // IWYU pragma: keep
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <vector>
#ifdef PATH_MAX
#define LUTE_PATH_MAX PATH_MAX
#else
#define LUTE_PATH_MAX 8192
#endif

namespace process
{

void convertCRLFtoLF(std::string& str)
{
    size_t writePos = 0;
    for (size_t readPos = 0; readPos < str.size(); ++readPos)
    {
        if (str[readPos] == '\r' && readPos + 1 < str.size() && str[readPos + 1] == '\n')
            continue; // Skip the '\r' in CRLF
        str[writePos++] = str[readPos];
    }
    str.resize(writePos);
}

struct ProcessHandle
{
    uv_process_t process;
    uv_pipe_t stdinPipe;
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

        if (!uv_is_closing((uv_handle_t*)&stdinPipe))
        {
            pendingCloses++;
            uv_read_stop((uv_stream_t*)&stdinPipe);
            uv_close((uv_handle_t*)&stdinPipe, closeCb);
        }

        if (!uv_is_closing((uv_handle_t*)&stdoutPipe))
        {
            pendingCloses++;
            uv_read_stop((uv_stream_t*)&stdoutPipe);
            uv_close((uv_handle_t*)&stdoutPipe, closeCb);
        }

        if (!uv_is_closing((uv_handle_t*)&stderrPipe))
        {
            pendingCloses++;
            uv_read_stop((uv_stream_t*)&stderrPipe);
            uv_close((uv_handle_t*)&stderrPipe, closeCb);
        }
        if (!uv_is_closing((uv_handle_t*)&process))
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
            // TODO: we should probably also put stdin in the output if it was unfinished? maybe?
            std::string finalStdout = stdoutData;
            std::string finalStderr = stderrData;
            std::string finalSignalStr = finalTermSignal ? std::to_string(finalTermSignal) : "";
            convertCRLFtoLF(finalStdout);
            convertCRLFtoLF(finalStderr);
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
                        lua_pushlstring(L, finalSignalStr.c_str(), finalSignalStr.size());
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

struct ProcessOptions
{
    std::string cwd;
    std::string stdioKind;
    std::map<std::string, std::string> env;
    std::string customShell; // only used by system()
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

const std::string kStdioKindDefault = "default";
const std::string kStdioKindInherit = "inherit";
const std::string kStdioKindNone = "none";
// TODO: add forwarding
// const std::string kStdioKindForward = "forward";

// helper function for run() and system()
int executionHelper(lua_State* L, std::vector<std::string> args, ProcessOptions opts)
{
    auto handle = std::make_shared<ProcessHandle>();
    handle->loop = getRuntimeLoop(L);
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
    if (!opts.env.empty())
    {
        // Copy current environment into the new environment
        uv_env_item_t* currentEnvItems;
        int currentEnvCount;
        int err = uv_os_environ(&currentEnvItems, &currentEnvCount);
        if (err != 0)
        {
            uv_os_free_environ(currentEnvItems, currentEnvCount);
            luaL_error(L, "Failed to get current environment: %s", uv_strerror(err));
        }
        for (int i = 0; i < currentEnvCount; i++)
        {
            if (currentEnvItems[i].name && currentEnvItems[i].value && opts.env.find(currentEnvItems[i].name) == opts.env.end())
            {
                opts.env[currentEnvItems[i].name] = currentEnvItems[i].value;
            }
        }
        uv_os_free_environ(currentEnvItems, currentEnvCount);

        // Turn the new environment into a char** array
        envStrings.reserve(opts.env.size());
        envPtr.reserve(opts.env.size() + 1);
        for (const auto& pair : opts.env)
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

    if (!opts.cwd.empty())
    {
        options.cwd = opts.cwd.c_str();
    }

    uv_pipe_init(handle->loop, &handle->stdinPipe, 0);
    uv_pipe_init(handle->loop, &handle->stdoutPipe, 0);
    uv_pipe_init(handle->loop, &handle->stderrPipe, 0);

    options.stdio_count = 3;
    uv_stdio_container_t stdio[3];
    if (opts.stdioKind == kStdioKindNone)
    {
    	stdio[0].flags = UV_IGNORE;
        stdio[1].flags = UV_IGNORE;
        stdio[2].flags = UV_IGNORE;
    }
    else if (opts.stdioKind == kStdioKindInherit)
    {
        stdio[0].flags = UV_INHERIT_FD;
        stdio[0].data.fd = fileno(stdin);
        stdio[1].flags = UV_INHERIT_FD;
        stdio[1].data.fd = fileno(stdout);
        stdio[2].flags = UV_INHERIT_FD;
        stdio[2].data.fd = fileno(stderr);
    }
    else if (opts.stdioKind == kStdioKindDefault || opts.stdioKind.empty())
    {
	    stdio[0].flags = static_cast<uv_stdio_flags>(UV_CREATE_PIPE | UV_WRITABLE_PIPE);
	    stdio[0].data.stream = (uv_stream_t*)&handle->stdinPipe;
        stdio[1].flags = static_cast<uv_stdio_flags>(UV_CREATE_PIPE | UV_WRITABLE_PIPE);
        stdio[1].data.stream = (uv_stream_t*)&handle->stdoutPipe;
        stdio[2].flags = static_cast<uv_stdio_flags>(UV_CREATE_PIPE | UV_WRITABLE_PIPE);
        stdio[2].data.stream = (uv_stream_t*)&handle->stderrPipe;
    }
    else
    {
        luaL_error(L, "Invalid stdio kind: %s", opts.stdioKind.c_str());
    }
    options.stdio = stdio;

    handle->process.data = handle.get();
    handle->stdinPipe.data = handle.get();
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
    }

    uv_read_start((uv_stream_t*)&handle->stdoutPipe, allocBuffer, onPipeRead);
    uv_read_start((uv_stream_t*)&handle->stderrPipe, allocBuffer, onPipeRead);

    return lua_yield(L, 0);
}

ProcessOptions parseOptions(lua_State* L, int index)
{
    ProcessOptions opts;

    if (lua_isnoneornil(L, index))
    {
        return opts; // use defaults
    }

    if (!lua_istable(L, index))
    {
        luaL_error(L, "process options must be a table");
    }

    lua_getfield(L, index, "system");
    if (!lua_isnil(L, -1))
    {
        opts.customShell = luaL_checkstring(L, -1);
    }
    lua_pop(L, 1);

    lua_getfield(L, index, "cwd");
    if (!lua_isnil(L, -1))
    {
        opts.cwd = luaL_checkstring(L, -1);
    }
    lua_pop(L, 1);

    lua_getfield(L, index, "stdio");
    if (!lua_isnil(L, -1))
    {
        opts.stdioKind = luaL_checkstring(L, -1);
    }
    lua_pop(L, 1);

    lua_getfield(L, index, "env");
    if (!lua_isnil(L, -1))
    {
        if (lua_istable(L, -1))
        {
            lua_pushnil(L);
            while (lua_next(L, -2))
            {
                opts.env[luaL_checkstring(L, -2)] = luaL_checkstring(L, -1);
                lua_pop(L, 1);
            }
        }
        else
        {
            luaL_error(L, "process option 'env' must be a table");
        }
    }
    lua_pop(L, 1);

    return opts;
}

int run(lua_State* L)
{
    if (!lua_istable(L, 1))
    {
        luaL_error(L, "process.run expects a table of arguments as the first parameter");
    }

    std::vector<std::string> args;
    int len = lua_objlen(L, 1);
    for (int i = 1; i <= len; i++)
    {
        lua_rawgeti(L, 1, i);
        args.push_back(luaL_checkstring(L, -1));
        lua_pop(L, 1);
    }

    if (args.empty())
    {
        luaL_error(L, "process.run requires a non-empty table of arguments");
    }
    if (args[0].empty())
    {
        luaL_error(L, "process.run requires a non-empty command as the first argument");
    }

    ProcessOptions opts = parseOptions(L, 2);
    return executionHelper(L, args, opts);
}

int system(lua_State* L)
{
    std::string command = luaL_checkstring(L, 1);
    if (command.empty())
    {
        luaL_error(L, "process.system requires a non-empty string as the command");
    }

    ProcessOptions opts = parseOptions(L, 2);

#ifdef _WIN32
    const char* shellVar = "COMSPEC";
    const char* shellFallback = "cmd.exe";
    const char* shellArg = "/c";
#else
    const char* shellVar = "SHELL";
    const char* shellFallback = "/bin/sh";
    const char* shellArg = "-c";
#endif

    std::string resolvedShell;
    if (opts.customShell.empty())
    {
        char shellBuffer[1024];
        size_t shellSize = sizeof(shellBuffer);
        int result = uv_os_getenv(shellVar, shellBuffer, &shellSize);
        resolvedShell = result == 0 ? shellBuffer : shellFallback;
    }
    else
    {
        resolvedShell = opts.customShell;
    }

    return executionHelper(L, {resolvedShell, shellArg, command}, opts);
}

int homedir(lua_State* L)
{
    auto result = uvutils::getStringFromUv(uv_os_homedir);
    if (uvutils::UvError* error = result.get_if<uvutils::UvError>())
        luaL_error(L, "failed to get home directory: %s", error->toString().c_str());

    std::string* homeDir = result.get_if<std::string>();
    lua_pushlstring(L, homeDir->c_str(), homeDir->size());
    return 1;
}

int exitFunc(lua_State* L)
{
    int exitCode = luaL_optinteger(L, 1, 0);

    // Exit with the provided code
    std::exit(exitCode);

    LUTE_UNREACHABLE();
}

int cwd(lua_State* L)
{
    auto result = uvutils::getStringFromUv(uv_cwd);
    if (uvutils::UvError* error = result.get_if<uvutils::UvError>())
        luaL_error(L, "failed to get current working directory: %s", error->toString().c_str());

    std::string* cwd = result.get_if<std::string>();
    lua_pushlstring(L, cwd->c_str(), cwd->size());
    return 1;
};

int execPath(lua_State* L)
{
    std::string error;
    std::optional<std::string> execPath = Process::getExecPath(&error);
    if (!execPath)
        luaL_error(L, "Failed to get executable path: %s", error.c_str());

    lua_pushlstring(L, execPath->c_str(), execPath->size());
    return 1;
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

    ~EnvIter()
    {
        if (items)
        {
            uv_os_free_environ(items, count);
            items = nullptr;
            count = 0;
        }
    }
};

static int envIterNext(lua_State* L)
{
    EnvIter* iter = (EnvIter*)lua_touserdata(L, lua_upvalueindex(1));

    if (iter->index >= iter->count)
    {
        return 0;
    }

    uv_env_item_t item = iter->items[iter->index];
    lua_pushstring(L, item.name);
    lua_pushstring(L, item.value);
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

    EnvIter* iter = (EnvIter*)lua_newuserdatadtor(
        L,
        sizeof(EnvIter),
        [](void* ptr)
        {
            std::destroy_at(static_cast<EnvIter*>(ptr));
        }
    );

    iter->items = items;
    iter->count = count;
    iter->index = 0;

    lua_pushvalue(L, -1);
    lua_pushcclosure(L, envIterNext, "envIterNext", 1);

    return 1;
}

} // namespace process

static const luaL_Reg processEnvMeta[] =
    {{"__index", process::envIndex}, {"__newindex", process::envNewindex}, {"__iter", process::envIter}, {nullptr, nullptr}};

std::optional<std::string> Process::getExecPath(std::string* error)
{
    // Executable path is not expected to change during process lifetime, so we
    // can safely cache it after the first retrieval.
    static std::optional<std::string> cachedPath = std::nullopt;
    if (cachedPath)
        return *cachedPath;

    char buf[LUTE_PATH_MAX];
    size_t len = sizeof(buf);

    if (int status = uv_exepath(buf, &len); status < 0)
    {
        if (error)
            *error = uv_strerror(status);
        return std::nullopt;
    }

    cachedPath = std::string(buf, len);
    return *cachedPath;
}

const char* const Process::properties[] = {"env", "args"};

const luaL_Reg Process::lib[] = {
    {"run", process::run},
    {"system", process::system},
    {"homedir", process::homedir},
    {"cwd", process::cwd},
    {"exit", process::exitFunc},
    {"execPath", process::execPath},
    {nullptr, nullptr},
};

int Process::pushLibrary(lua_State* L)
{
    lua_createtable(L, 0, std::size(Process::lib) + std::size(Process::properties));

    for (auto& [name, func] : Process::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_newtable(L);
    luaL_newmetatable(L, "process.env");
    luaL_register(L, nullptr, processEnvMeta);
    lua_setmetatable(L, -2);
    lua_setfield(L, -2, "env");

    // Create process.args table
    Runtime* runtime = getRuntime(L);
    if (runtime)
    {
        lua_createtable(L, static_cast<int>(runtime->args.size()), 0);
        for (int i = 0; i < static_cast<int>(runtime->args.size()); ++i)
        {
            lua_pushlstring(L, runtime->args[i].c_str(), runtime->args[i].size());
            lua_rawseti(L, -2, i + 1);
        }
    }
    else
    {
        lua_createtable(L, 0, 0);
    }
    lua_setreadonly(L, -1, 1); // args table
    lua_setfield(L, -2, "args");

    lua_setreadonly(L, -1, 1); // process table

    return 1;
}

int luaopen_process(lua_State* L)
{
    return Process::openAsGlobal(L);
}

int luteopen_process(lua_State* L)
{
    return Process::pushLibrary(L);
}
