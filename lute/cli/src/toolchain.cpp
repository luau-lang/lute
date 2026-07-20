#include "lute/toolchain.h"

#include "lute/clicommands.h"
#include "lute/options.h"
#include "lute/process.h"
#include "lute/reporter.h"
#include "lute/requiresetup.h"
#include "lute/runtime.h"

#include "Luau/Compiler.h"
#include "Luau/FileUtils.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include <cstring>
#include <optional>
#include <string>
#include <vector>

#ifdef _WIN32
#include <process.h>
#else
#include <unistd.h>
#endif

static const char* kSkipDispatchEnv = "LUTE_SKIP_DISPATCH";

static bool isEnvSet(const char* key)
{
    char buffer[256];
    size_t size = sizeof(buffer);
    int err = uv_os_getenv(key, buffer, &size);
    if (err == UV_ENOBUFS)
        return true; // set, value longer than the buffer
    return err == 0 && size > 0;
}

static void reExecInto(std::string target, int argc, char** argv, LuteReporter& reporter)
{
    if (int err = uv_os_setenv(kSkipDispatchEnv, "1"); err != 0)
    {
        reporter.formatError("Failed to set %s: %s\n", kSkipDispatchEnv, uv_strerror(err));
        return;
    }

    std::vector<char*> childArgv;
    childArgv.reserve(static_cast<size_t>(argc) + 1);
    childArgv.push_back(target.data());
    for (int i = 1; i < argc; i++)
        childArgv.push_back(argv[i]);
    childArgv.push_back(nullptr);

#ifdef _WIN32
    _execv(target.c_str(), childArgv.data());
#else
    execv(target.c_str(), childArgv.data());
#endif

    reporter.formatError("Failed to re-exec lute at '%s'.\n", target.c_str());
}

bool dispatchToPinnedLute(int argc, char** argv, LuteReporter& reporter)
{
    if (argc < 2)
        return true;

    if (strcmp(argv[1], "self") == 0 || strcmp(argv[1], "toolchain") == 0)
        return true;

    if (isEnvSet(kSkipDispatchEnv))
        return true;

    CliModuleResult module = getCliModule("@cli/toolchain/dispatch.luau");
    if (module.type != CliModuleType::Module)
    {
        reporter.reportError("Internal error: toolchain dispatch module not found.\n");
        return false;
    }

    Runtime runtime{reporter};
    setupCliCommandState(runtime, setupVersionLibrary);

    std::string bytecode = Luau::compile(std::string(module.contents), copts());
    std::optional<std::string> resolved;
    bool failed = false;
    bool ran = runtime.runBytecode(
        bytecode,
        "@@cli/toolchain/dispatch.luau",
        0,
        nullptr,
        [&](lua_State* entry)
        {
            // A completion handler suppresses the runtime's own error reporting, so
            // surface any failure here to keep an invalid pin visible and non-zero.
            runtime.addThreadCompletionHandler(
                entry,
                ThreadCompletionHandler{
                    [&](lua_State* thread, int status)
                    {
                        if (status != LUA_OK)
                        {
                            runtime.reportError(thread);
                            failed = true;
                        }
                        else if (lua_gettop(thread) > 1)
                        {
                            reporter.reportError("Internal error: toolchain dispatch must return at most one value.\n");
                            failed = true;
                        }
                        else if (int type = lua_type(thread, 1); type == LUA_TSTRING)
                        {
                            // The module returns the pinned binary path, or nil to stay on the current binary.
                            resolved = lua_tostring(thread, 1);
                        }
                        else if (type != LUA_TNIL && type != LUA_TNONE)
                        {
                            reporter.reportError("Internal error: toolchain dispatch must return a string or nil.\n");
                            failed = true;
                        }
                    }
                }
            );
        }
    );

    if (!ran || failed)
        return false;

    if (!resolved)
        return true;

    std::string errorMsg;
    std::optional<std::string> exePath = Process::getExecPath(&errorMsg);
    if (!exePath)
    {
        reporter.formatError("Failed to get executable path: %s", errorMsg.c_str());
        return false;
    }

    // Nothing to dispatch to when the pin already points at the running binary.
    if (normalizePath(*exePath) == normalizePath(*resolved))
        return true;

    reExecInto(*resolved, argc, argv, reporter);
    return false;
}
