#include "Luau/Common.h"
#include "Luau/CodeGen.h"
#include "Luau/Compiler.h"
#include "Luau/FileUtils.h"
#include "Luau/Parser.h"
#include "Luau/Require.h"

#include "lua.h"
#include "lualib.h"
#include "uv.h"

#include "lute/fs.h"
#include "lute/luau.h"
#include "lute/net.h"
#include "lute/options.h"
#include "lute/process.h"
#include "lute/system.h"
#include "lute/ref.h"
#include "lute/require.h"
#include "lute/runtime.h"
#include "lute/task.h"
#include "lute/vm.h"

#include "tc.h"

#ifdef _WIN32
#include <Windows.h>
#endif

#include <string>
#include <vector>

static int program_argc = 0;
static char** program_argv = nullptr;

static void* createCliRequireContext(lua_State* L)
{
    void* ctx = lua_newuserdatadtor(
        L,
        sizeof(RequireCtx),
        [](void* ptr)
        {
            static_cast<RequireCtx*>(ptr)->~RequireCtx();
        }
    );

    if (!ctx)
        luaL_error(L, "unable to allocate RequireCtx");

    ctx = new (ctx) RequireCtx{};

    // Store RequireCtx in the registry to keep it alive for the lifetime of
    // this lua_State. Memory address is used as a key to avoid collisions.
    lua_pushlightuserdata(L, ctx);
    lua_insert(L, -2);
    lua_settable(L, LUA_REGISTRYINDEX);

    return ctx;
}

lua_State* setupState(Runtime& runtime)
{
    // Separate VM for data copies
    runtime.dataCopy.reset(luaL_newstate());

    runtime.globalState.reset(luaL_newstate());

    lua_State* L = runtime.globalState.get();

    runtime.GL = L;

    lua_setthreaddata(L, &runtime);

    /* register new libraries */
    if (Luau::CodeGen::isSupported())
        Luau::CodeGen::create(L);

    // register the builtin tables
    luaL_openlibs(L);

    luaL_findtable(L, LUA_REGISTRYINDEX, "_MODULES", 1);

    luteopen_fs(L);
    lua_setfield(L, -2, "@lute/fs");

    luteopen_luau(L);
    lua_setfield(L, -2, "@lute/luau");

    luteopen_net(L);
    lua_setfield(L, -2, "@lute/net");

    luteopen_process(L);
    lua_setfield(L, -2, "@lute/process");

    luteopen_task(L);
    lua_setfield(L, -2, "@lute/task");

    luteopen_vm(L);
    lua_setfield(L, -2, "@lute/vm");

    luteopen_system(L);
    lua_setfield(L, -2, "@lute/system");

    lua_pop(L, 1);

    luaopen_require(L, requireConfigInit, createCliRequireContext(L));

    lua_pushnil(L);
    lua_setglobal(L, "setfenv");

    lua_pushnil(L);
    lua_setglobal(L, "getfenv");

    luaL_sandbox(L);

    return L;
}

bool setupArguments(lua_State* L, int argc, char** argv)
{
    if (!lua_checkstack(L, argc))
        return false;

    for (int i = 0; i < argc; ++i)
        lua_pushstring(L, argv[i]);

    return true;
}

static bool runFile(Runtime& runtime, const char* name, lua_State* GL)
{
    std::optional<std::string> source = readFile(name);
    if (!source)
    {
        fprintf(stderr, "Error opening %s\n", name);
        return false;
    }

    // module needs to run in a new thread, isolated from the rest
    lua_State* L = lua_newthread(GL);

    // new thread needs to have the globals sandboxed
    luaL_sandboxthread(L);

    // ignore file extension when storing module's chunkname
    std::string chunkname = "@";
    std::string_view nameView = name;
    if (size_t dotPos = nameView.find_last_of('.'); dotPos != std::string_view::npos)
    {
        nameView.remove_suffix(nameView.size() - dotPos);
    }
    chunkname += nameView;

    std::string bytecode = Luau::compile(*source, copts());

    if (luau_load(L, chunkname.c_str(), bytecode.data(), bytecode.size(), 0) != 0)
    {
        if (const char* str = lua_tostring(L, -1))
            fprintf(stderr, "%s", str);
        else
            fprintf(stderr, "Failed to load bytecode");

        lua_pop(GL, 1);
        return false;
    }

    if (getCodegenEnabled())
    {
        Luau::CodeGen::CompilationOptions nativeOptions;
        Luau::CodeGen::compile(L, -1, nativeOptions);
    }

    if (!setupArguments(L, program_argc, program_argv))
    {
        fprintf(stderr, "Failed to pass arguments to Luau");
        lua_pop(GL, 1);
        return false;
    }

    runtime.GL = GL;
    runtime.runningThreads.push_back({true, getRefForThread(L), program_argc});

    lua_pop(GL, 1);

    return runtime.runToCompletion();
}

static void displayHelp(const char* argv0)
{
    printf("Usage: %s <command> [options] [arguments...]\n", argv0);
    printf("\n");
    printf("Commands:\n");
    printf("  run (default)   Run a Luau script.\n");
    printf("  check           Type check Luau files.\n");
    printf("\n");
    printf("Run Options (when using 'run' or no command):\n");
    printf("  %s [run] <script.luau> [args...]\n", argv0);
    printf("    Executes the script, passing [args...] to it.\n");
    printf("\n");
    printf("Check Options:\n");
    printf("  %s check <file1.luau> [file2.luau...]\n", argv0);
    printf("    Performs a type check on the specified files.\n");
    printf("\n");
    printf("General Options:\n");
    printf("  -h, --help    Display this usage message.\n");
}

static void displayRunHelp(const char* argv0)
{
    printf("Usage: %s run <script.luau> [args...]\n", argv0);
    printf("\n");
    printf("Run Options:\n");
    printf("  -h, --help    Display this usage message.\n");
}

static void displayCheckHelp(const char* argv0)
{
    printf("Usage: %s check <file1.luau> [file2.luau...]\n", argv0);
    printf("\n");
    printf("Check Options:\n");
    printf("  -h, --help    Display this usage message.\n");
}

static int assertionHandler(const char* expr, const char* file, int line, const char* function)
{
    printf("%s(%d): ASSERTION FAILED: %s\n", file, line, expr);
    return 1;
}

int handleRunCommand(int argc, char** argv, int argOffset)
{
    const char* filePath = nullptr;

    for (int i = argOffset; i < argc; ++i)
    {
        const char* currentArg = argv[i];

        if (strcmp(currentArg, "-h") == 0 || strcmp(currentArg, "--help") == 0)
        {
            displayRunHelp(argv[0]);
            return 0;
        }
        else if (currentArg[0] == '-')
        {
            fprintf(stderr, "Error: Unrecognized option '%s' for 'run' command.\n\n", currentArg);
            displayRunHelp(argv[0]);
            return 1;
        }
        else
        {
            filePath = currentArg;
            program_argc = argc - i;
            program_argv = &argv[i];
            break;
        }
    }

    if (!filePath)
    {
        fprintf(stderr, "Error: No file specified for 'run' command.\n\n");
        displayRunHelp(argv[0]);
        return 1;
    }

    Runtime runtime;
    lua_State* L = setupState(runtime);

    bool success = runFile(runtime, filePath, L);
    return success ? 0 : 1;
}

int handleCheckCommand(int argc, char** argv, int argOffset)
{
    std::vector<std::string> files;

    for (int i = argOffset; i < argc; ++i)
    {
        const char* currentArg = argv[i];

        if (strcmp(currentArg, "-h") == 0 || strcmp(currentArg, "--help") == 0)
        {
            displayCheckHelp(argv[0]);
            return 0;
        }
        else if (currentArg[0] == '-')
        {
            fprintf(stderr, "Error: Unrecognized option '%s' for 'check' command.\n\n", currentArg);
            displayCheckHelp(argv[0]);
            return 1;
        }
        else
        {
            files.push_back(currentArg);
        }
    }

    if (files.empty())
    {
        fprintf(stderr, "Error: No files specified for 'check' command.\n\n");
        displayCheckHelp(argv[0]);
        return 1;
    }

    return typecheck(files);
}

int main(int argc, char** argv)
{
    Luau::assertHandler() = assertionHandler;

#ifdef _WIN32
    SetConsoleOutputCP(CP_UTF8);
#endif

    if (argc < 2)
    {
        // TODO: REPL?
        displayHelp(argv[0]);
        return 0;
    }

    const char* command = argv[1];
    int argOffset = 2;

    if (strcmp(command, "run") == 0)
    {
        return handleRunCommand(argc, argv, argOffset);
    }
    else if (strcmp(command, "check") == 0)
    {
        return handleCheckCommand(argc, argv, argOffset);
    }
    else if (strcmp(command, "-h") == 0 || strcmp(command, "--help") == 0)
    {
        displayHelp(argv[0]);
        return 0;
    }
    else
    {
        // Default to 'run' command
        argOffset = 1;
        return handleRunCommand(argc, argv, argOffset);
    }
}
