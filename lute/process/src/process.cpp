#include "lute/process.h"

#include "lute/common.h"
#include "lute/processhandle.h"
#include "lute/runtime.h"
#include "lute/uvutils.h"
#include "os_signal.h"

#include "Luau/Common.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include <climits> // IWYU pragma: keep
#include <memory>
#include <string>
#include <vector>
#ifdef PATH_MAX
#define LUTE_PATH_MAX PATH_MAX
#else
#define LUTE_PATH_MAX 8192
#endif

namespace process
{

static int pidFunc(lua_State* L)
{
    lua_pushinteger(L, uv_os_getpid());
    return 1;
}

// helper function for run() and system()
int executionHelper(lua_State* L, std::vector<std::string> args, ProcessOptions opts)
{
    auto handle = std::make_shared<ProcessHandle>(L, opts, args, "Process Spawn");
    handle->self = handle;
    handle->spawn(L);
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
        if (opts.stdioKind != kStdioKindNone && opts.stdioKind != kStdioKindDefault && opts.stdioKind != kStdioKindInherit)
        {
            luaL_error(L, "Invalid stdio kind: %s", opts.stdioKind.c_str());
        }
    }
    else
    {
        opts.stdioKind = kStdioKindDefault;
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
        if (!buffer)
            luaL_error(L, "out of memory");

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
    {"onSignal", process::signalFunc},
    {"pid", process::pidFunc},
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

    registerSignalHandle(L);

    return 1;
}

LUTE_API int luaopen_process(lua_State* L)
{
    return Process::openAsGlobal(L);
}

LUTE_API int luteopen_process(lua_State* L)
{
    return Process::pushLibrary(L);
}
