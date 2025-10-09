#include "Luau/Common.h"
#include "Luau/CodeGen.h"
#include "Luau/Compiler.h"
#include "Luau/FileUtils.h"
#include "Luau/Parser.h"
#include "Luau/Require.h"

#include "lua.h"
#include "lualib.h"
#include "uv.h"

#include "lute/clicommands.h"
#include "lute/clivfs.h"
#include "lute/compile.h"
#include "lute/options.h"
#include "lute/ref.h"
#include "lute/require.h"
#include "lute/runtime.h"
#include "lute/tc.h"
#include "lute/version.h"

#ifdef _WIN32
#include <Windows.h>
#endif

#include <iostream>
#include <string>
#include <vector>

static int program_argc = 0;
static char** program_argv = nullptr;

void* createCliRequireContext(lua_State* L)
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

    ctx = new (ctx) RequireCtx{CliVfs{}};

    // Store RequireCtx in the registry to keep it alive for the lifetime of
    // this lua_State. Memory address is used as a key to avoid collisions.
    lua_pushlightuserdata(L, ctx);
    lua_insert(L, -2);
    lua_settable(L, LUA_REGISTRYINDEX);

    return ctx;
}

lua_State* setupCliState(Runtime& runtime)
{
    return setupState(
        runtime,
        [](lua_State* L)
        {
            if (Luau::CodeGen::isSupported())
                Luau::CodeGen::create(L);

            luaopen_require(L, requireConfigInit, createCliRequireContext(L));
        }
    );
}

bool setupArguments(lua_State* L, int argc, char** argv)
{
    if (!lua_checkstack(L, argc))
        return false;

    for (int i = 0; i < argc; ++i)
        lua_pushstring(L, argv[i]);

    return true;
}

static bool runBytecode(Runtime& runtime, const std::string& bytecode, const std::string& chunkname, lua_State* GL)
{
    // module needs to run in a new thread, isolated from the rest
    lua_State* L = lua_newthread(GL);

    // new thread needs to have the globals sandboxed
    luaL_sandboxthread(L);

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

static bool runFile(Runtime& runtime, const char* name, lua_State* GL)
{
    if (isDirectory(name))
    {
        fprintf(stderr, "Error: %s is a directory\n", name);
        return false;
    }

    std::optional<std::string> source = readFile(name);
    if (!source)
    {
        fprintf(stderr, "Error opening %s\n", name);
        return false;
    }

    std::string chunkname = "@" + normalizePath(name);

    std::string bytecode = Luau::compile(*source, copts());

    return runBytecode(runtime, bytecode, chunkname, GL);
}

static void displayHelp(const char* argv0)
{
    printf("Usage: lute <command> [options] [arguments...]\n");
    printf("\n");
    printf("Commands:\n");
    printf("  run (default)   Run a Luau script.\n");
    printf("  check           Type check Luau files.\n");
    printf("  compile         Compile a Luau script into the executable.\n");
    printf("  setup           Generate type definition files for the language server.");
    printf("\n");
    printf("Run Options (when using 'run' or no command):\n");
    printf("  lute [run] <script.luau> [args...]\n");
    printf("    Executes the script, passing [args...] to it.\n");
    printf("\n");
    printf("Check Options:\n");
    printf("  lute check <file1.luau> [file2.luau...]\n");
    printf("    Performs a type check on the specified files.\n");
    printf("\n");
    printf("Compile Options:\n");
    printf("  lute compile <script.luau> [output_executable]\n");
    printf("    Compiles the script, embedding it into a new executable.\n");
    printf("\n");
    printf("Setup Options:\n");
    printf("  lute setup");
    printf("    Generates type definition files for the language server.\n");
    printf("\n");
    printf("General Options:\n");
    printf("  -h, --help    Display this usage message.\n");
    printf("      --version Show the lute version.\n");
}

static void displayVersion()
{
    printf("%s\n", LUTE_VERSION_FULL);
}

static void displayRunHelp(const char* argv0)
{
    printf("Usage: lute run <script.luau> [args...]\n");
    printf("\n");
    printf("Run Options:\n");
    printf("  -h, --help    Display this usage message.\n");
}

static void displayCheckHelp(const char* argv0)
{
    printf("Usage: lute check <file1.luau> [file2.luau...]\n");
    printf("\n");
    printf("Check Options:\n");
    printf("  -h, --help    Display this usage message.\n");
}

static void displayCompileHelp(const char* argv0)
{
    printf("Usage: lute compile <script.luau> [output_executable]\n");
    printf("\n");
    printf("Compile Options:\n");
    printf("  output_executable    Optional name for the compiled executable.\n");
    printf("                       Defaults to '<script_name>_compiled'.\n");
    printf("  -h, --help           Display this usage message.\n");
}

static int assertionHandler(const char* expr, const char* file, int line, const char* function)
{
    printf("%s(%d): ASSERTION FAILED: %s\n", file, line, expr);
    return 1;
}

static std::optional<std::string> getValidPath(std::string filePath)
{
    auto getWithRequireByStringSemantics = [](std::string filePath) -> std::optional<std::string>
    {
        std::string normalized = normalizePath(std::move(filePath));

        std::string rootOfPath;
        std::string restOfPath = normalized;
        if (size_t firstSlash = normalized.find_first_of("\\/"); firstSlash != std::string::npos)
        {
            rootOfPath = normalized.substr(0, firstSlash);
            restOfPath = normalized.substr(firstSlash + 1);
        }

        std::optional<ModulePath> mp = ModulePath::create(std::move(rootOfPath), std::move(restOfPath), isFile, isDirectory);
        if (!mp)
            return std::nullopt;

        ResolvedRealPath resolved = mp->getRealPath();
        if (resolved.status != NavigationStatus::Success)
            return std::nullopt;

        if (resolved.type == ResolvedRealPath::Type::File)
            return resolved.realPath;

        return std::nullopt;
    };

    if (std::optional<std::string> path = getWithRequireByStringSemantics(filePath))
    {
        return *path;
    }

    // Only fallback to checking .lute/* if the original path has no extension.
    if (filePath.find('.') != std::string::npos)
        return std::nullopt;

    std::string fallbackPath = joinPaths(".lute", filePath);
    size_t fallbackSize = fallbackPath.size();

    for (const auto& ext : {".luau", ".lua"})
    {
        fallbackPath.resize(fallbackSize);
        fallbackPath += ext;

        if (isFile(fallbackPath))
            return fallbackPath;
    }

    return std::nullopt;
}

int handleRunCommand(int argc, char** argv, int argOffset)
{
    std::string filePath;

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

    if (filePath.empty())
    {
        fprintf(stderr, "Error: No file specified for 'run' command.\n\n");
        displayRunHelp(argv[0]);
        return 1;
    }

    Runtime runtime;
    lua_State* L = setupCliState(runtime);

    std::optional<std::string> validPath = getValidPath(filePath);
    if (!validPath)
    {
        std::cerr << "Error: File '" << filePath << "' does not exist.\n";
        return 1;
    }

    bool success = runFile(runtime, validPath->c_str(), L);
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

int handleCompileCommand(int argc, char** argv, int argOffset)
{
    std::string inputFilePath;
    std::string outputFilePath;

    for (int i = argOffset; i < argc; ++i)
    {
        const char* currentArg = argv[i];

        if (strcmp(currentArg, "-h") == 0 || strcmp(currentArg, "--help") == 0)
        {
            displayCompileHelp(argv[0]);
            return 0;
        }
        else if (inputFilePath.empty())
        {
            inputFilePath = currentArg;
        }
        else if (outputFilePath.empty())
        {
            outputFilePath = currentArg;
        }
        else
        {
            fprintf(stderr, "Error: Too many arguments for 'compile' command.\n\n");
            displayCompileHelp(argv[0]);
            return 1;
        }
    }

    if (inputFilePath.empty())
    {
        fprintf(stderr, "Error: No input file specified for 'compile' command.\n\n");
        displayCompileHelp(argv[0]);
        return 1;
    }

    if (outputFilePath.empty())
    {
        std::string inputBase = inputFilePath;
        size_t lastSlash = inputBase.find_last_of("/");
        if (lastSlash != std::string::npos)
        {
            inputBase = inputBase.substr(lastSlash + 1);
        }
#ifdef _WIN32
        size_t lastBackslash = inputBase.find_last_of("\\");
        if (lastBackslash != std::string::npos)
        {
            inputBase = inputBase.substr(lastBackslash + 1);
        }
#endif
        size_t lastDot = inputBase.find_last_of('.');
        if (lastDot != std::string::npos)
        {
            inputBase = inputBase.substr(0, lastDot);
        }
        outputFilePath = inputBase;
#ifdef _WIN32
        outputFilePath += ".exe";
#endif
    }

    return compileScript(inputFilePath, outputFilePath, argv[0]);
}

int handleCliCommand(CliCommandResult result)
{
    Runtime runtime;
    lua_State* L = setupCliState(runtime);

    std::string bytecode = Luau::compile(std::string(result.contents), copts());
    return runBytecode(runtime, bytecode, "@" + result.path, L) ? 0 : 1;
}

int cliMain(int argc, char** argv)
{
    Luau::assertHandler() = assertionHandler;

    AppendedBytecodeResult embedded = checkForAppendedBytecode(argv[0]);
    if (embedded.found)
    {
        Runtime runtime;
        lua_State* GL = setupCliState(runtime);

        program_argc = argc;
        program_argv = argv;

        bool success = runBytecode(runtime, embedded.BytecodeData, "=__EMBEDDED__", GL);

        return success ? 0 : 1;
    }

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
    else if (strcmp(command, "compile") == 0)
    {
        return handleCompileCommand(argc, argv, argOffset);
    }
    else if (strcmp(command, "-h") == 0 || strcmp(command, "--help") == 0)
    {
        displayHelp(argv[0]);
        return 0;
    }
    else if (strcmp(command, "--version") == 0)
    {
        displayVersion();
        return 0;
    }
    else if (std::optional<CliCommandResult> result = getCliCommand(command); result)
    {
        program_argc = argc - argOffset;
        program_argv = &argv[argOffset];
        return handleCliCommand(*result);
    }
    else
    {
        // Default to 'run' command
        argOffset = 1;
        return handleRunCommand(argc, argv, argOffset);
    }
}
