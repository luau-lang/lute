#include "lute/climain.h"

#include "lute/bundlevfs.h"
#include "lute/clicommands.h"
#include "lute/clivfs.h"
#include "lute/compile.h"
#include "lute/crypto.h"
#include "lute/fs.h"
#include "lute/io.h"
#include "lute/luau.h"
#include "lute/luauflags.h"
#include "lute/net.h"
#include "lute/options.h"
#include "lute/process.h"
#include "lute/ref.h"
#include "lute/reporter.h"
#include "lute/require.h"
#include "lute/requirevfs.h"
#include "lute/runtime.h"
#include "lute/staticrequires.h"
#include "lute/system.h"
#include "lute/task.h"
#include "lute/tc.h"
#include "lute/time.h"
#include "lute/version.h"
#include "lute/vm.h"

#include "Luau/CodeGen.h"
#include "Luau/Common.h"
#include "Luau/Compiler.h"
#include "Luau/DenseHash.h"
#include "Luau/FileUtils.h"
#include "Luau/Require.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include <memory>

#ifdef _WIN32
#include <Windows.h>
#endif

#include <iostream>
#include <memory>
#include <string>
#include <vector>

static const char* HELP_STRING = R"(Usage: lute <command> [options] [arguments...]

Commands:
	run (default)   Run a Luau script.
	check           Type check Luau files.
	compile         Compile a Luau script into a standalone executable.
	setup           Generate type definition files for the language server.
    transform       Run a specified code transformation on specified Luau files.
    lint            Run linting rules on specified Luau files.

Run Options (when using 'run' or no command):
	lute [run] <script.luau> [args...]
		Executes the script, passing [args...] to it.

Check Options:
	lute check <file1.luau> [file2.luau...]
		Performs a type check on the specified files.

Compile Options:
	lute compile <entry.luau> [--output <executable>]
		Compiles entry point and auto-discovered dependencies into a standalone executable.

Setup Options:
	lute setup
		Generates type definition files for the language server.
            --with-luaurc           Defines aliases to the type definition files in the working directory's luaurc file.

Transform Options:
    lute transform <transformer script> [options...] <files...>
        Runs the specified code transformation on the provided Luau files.
            --dry-run               Runs the transformation without actually overwriting or deleting any files.
            --output <path>         Specifies an output file for a transformed file. Only valid when 
                                    transforming a single file. If not specified, files are overwritten in place.

Lint Options:
    lute lint [options...] <paths...>
        Runs linting rules on the specified Luau files.
            --rules <path>          Path to a single lint rule or a directory containing multiple lint rules.
                                    If not specified, default lint rules are used.

General Options:
	-h, --help    Display this usage message.
		--version Show the lute version.
)";

static const char* VERSION_STRING = LUTE_VERSION_FULL;

static const char* RUN_HELP_STRING = R"(Usage: lute run <script.luau> [args...]

Run Options:
	-h, --help    Display this usage message.
)";

static const char* CHECK_HELP_STRING = R"(Usage: lute check <file1.luau> [file2.luau...]

Check Options:
	-h, --help    Display this usage message.
)";

static const char* COMPILE_HELP_STRING = R"(Usage: lute compile <entry.luau> [options]

Compile Options:
	--output <path>         Name for the compiled executable.
		Defaults to entry file's base name (with .exe on Windows).
	--bundle-stats          Display bundle size and compression statistics.
	--show-require-graph    Print the require dependency graph.
	-h, --help              Display this usage message.
)";

void* createCliRequireContext(lua_State* L)
{
    void* ctx = lua_newuserdatadtor(
        L,
        sizeof(RequireCtx),
        [](void* ptr)
        {
            std::destroy_at(static_cast<RequireCtx*>(ptr));
        }
    );

    if (!ctx)
        luaL_error(L, "unable to allocate RequireCtx");

    ctx = new (ctx) RequireCtx{std::make_unique<RequireVfs>(CliVfs{})};

    // Store RequireCtx in the registry to keep it alive for the lifetime of
    // this lua_State. Memory address is used as a key to avoid collisions.
    lua_pushlightuserdata(L, ctx);
    lua_insert(L, -2);
    lua_settable(L, LUA_REGISTRYINDEX);

    return ctx;
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
        {"@lute/io", luteopen_io},
    }};

    for (const auto& [name, func] : libs)
    {
        lua_pushcfunction(L, luarequire_registermodule, nullptr);
        lua_pushstring(L, name);
        func(L);
        lua_call(L, 2, 0);
    }
}

void* createBundleRequireContext(
    lua_State* L,
    Luau::DenseHashMap<std::string, std::string> luaurcFiles,
    Luau::DenseHashMap<std::string, std::string> bundleMap
)
{
    void* ctx = lua_newuserdatadtor(
        L,
        sizeof(RequireCtx),
        [](void* ptr)
        {
            std::destroy_at(static_cast<RequireCtx*>(ptr));
        }
    );

    if (!ctx)
        luaL_error(L, "unable to allocate RequireCtx");
    ctx = new (ctx) RequireCtx{std::make_unique<RequireVfs>(BundleVfs{std::move(luaurcFiles), std::move(bundleMap)})};

    // Store RequireCtx in the registry to keep it alive for the lifetime of
    // this lua_State. Memory address is used as a key to avoid collisions.
    lua_pushlightuserdata(L, ctx);
    lua_insert(L, -2);
    lua_settable(L, LUA_REGISTRYINDEX);

    return ctx;
}

lua_State* setupCliState(Runtime& runtime, std::function<void(lua_State*)> preSandboxInit)
{
    return setupState(
        runtime,
        [preSandboxInit = std::move(preSandboxInit)](lua_State* L)
        {
            luteopen_libs(L);

            if (Luau::CodeGen::isSupported())
                Luau::CodeGen::create(L);

            luaopen_require(L, requireConfigInit, createCliRequireContext(L));
            if (preSandboxInit)
                preSandboxInit(L);
        }
    );
}

lua_State* setupBundleState(
    Runtime& runtime,
    Luau::DenseHashMap<std::string, std::string> luaurcFiles,
    Luau::DenseHashMap<std::string, std::string> bundleMap
)
{
    return setupState(
        runtime,
        [luaurcFiles = std::move(luaurcFiles), bundleMap = std::move(bundleMap)](lua_State* L)
        {
            luteopen_libs(L);
            if (Luau::CodeGen::isSupported())
                Luau::CodeGen::create(L);

            luaopen_require(L, requireConfigInit, createBundleRequireContext(L, std::move(luaurcFiles), std::move(bundleMap)));
        }
    );
}

static bool setupArguments(lua_State* L, int argc, char** argv)
{
    if (!lua_checkstack(L, argc))
        return false;

    for (int i = 0; i < argc; ++i)
        lua_pushstring(L, argv[i]);

    return true;
}

bool runBytecode(
    Runtime& runtime,
    const std::string& bytecode,
    const std::string& chunkname,
    lua_State* GL,
    int program_argc,
    char** program_argv,
    LuteReporter& reporter
)
{
    // module needs to run in a new thread, isolated from the rest
    lua_State* L = lua_newthread(GL);

    // new thread needs to have the globals sandboxed
    luaL_sandboxthread(L);

    if (luau_load(L, chunkname.c_str(), bytecode.data(), bytecode.size(), 0) != 0)
    {
        if (const char* str = lua_tostring(L, -1))
            reporter.reportError(str);
        else
            reporter.reportError("Failed to load bytecode");

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
        reporter.reportError("Failed to pass arguments to Luau");
        lua_pop(GL, 1);
        return false;
    }

    runtime.GL = GL;
    runtime.runningThreads.push_back({true, getRefForThread(L), program_argc});

    lua_pop(GL, 1);

    return runtime.runToCompletion();
}

static bool runFile(Runtime& runtime, const char* name, lua_State* GL, int program_argc, char** program_argv, LuteReporter& reporter)
{
    if (isDirectory(name))
    {
        reporter.formatError("Error: %s is a directory", name);
        return false;
    }

    std::optional<std::string> source = readFile(name);
    if (!source)
    {
        reporter.formatError("Error opening %s", name);
        return false;
    }

    std::string chunkname = "@" + normalizePath(name);

    std::string bytecode = Luau::compile(*source, copts());

    return runBytecode(runtime, bytecode, chunkname, GL, program_argc, program_argv, reporter);
}

static int assertionHandler(const char* expr, const char* file, int line, const char* function)
{
    printf("%s(%d): ASSERTION FAILED: %s\n", file, line, expr);
    return 1;
}

static std::optional<std::string> getWithRequireByStringSemantics(std::string filePath)
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

    if (resolved.type == ResolvedRealPath::PathType::File)
        return resolved.realPath;

    return std::nullopt;
};

static std::optional<std::string> getValidPath(std::string filePath)
{
    if (std::optional<std::string> path = getWithRequireByStringSemantics(filePath))
        return *path;

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

int handleRunCommand(int argc, char** argv, int argOffset, LuteReporter& reporter)
{
    std::string filePath;
    int program_argc = 0;
    char** program_argv = nullptr;

    for (int i = argOffset; i < argc; ++i)
    {
        const char* currentArg = argv[i];

        if (strcmp(currentArg, "-h") == 0 || strcmp(currentArg, "--help") == 0)
        {
            reporter.reportOutput(RUN_HELP_STRING);
            return 0;
        }
        else if (currentArg[0] == '-')
        {
            reporter.formatError("Error: Unrecognized option '%s' for 'run' command.", currentArg);
            reporter.reportOutput(RUN_HELP_STRING);
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
        reporter.reportError("Error: No file specified for 'run' command.");
        reporter.reportOutput(RUN_HELP_STRING);
        return 1;
    }

    Runtime runtime;
    lua_State* L = setupCliState(runtime);

    std::optional<std::string> validPath = getValidPath(filePath);
    if (!validPath)
    {
        reporter.formatError("Error: File '%s' does not exist.", filePath.c_str());
        return 1;
    }

    bool success = runFile(runtime, validPath->c_str(), L, program_argc, program_argv, reporter);
    return success ? 0 : 1;
}

int handleCheckCommand(int argc, char** argv, int argOffset, LuteReporter& reporter)
{
    std::vector<std::string> files;

    for (int i = argOffset; i < argc; ++i)
    {
        const char* currentArg = argv[i];

        if (strcmp(currentArg, "-h") == 0 || strcmp(currentArg, "--help") == 0)
        {
            reporter.reportOutput(CHECK_HELP_STRING);
            return 0;
        }
        else if (currentArg[0] == '-')
        {
            reporter.formatError("Error: Unrecognized option '%s' for 'check' command.", currentArg);
            reporter.reportOutput(CHECK_HELP_STRING);
            return 1;
        }
        else
        {
            files.push_back(currentArg);
        }
    }

    if (files.empty())
    {
        reporter.reportError("Error: No files specified for 'check' command.");
        reporter.reportOutput(CHECK_HELP_STRING);
        return 1;
    }

    return typecheck(files, reporter);
}

int handleCompileCommand(int argc, char** argv, int argOffset, LuteReporter& reporter)
{
    std::string filePath;
    std::string outputPath;
    bool bundleStats = false;
    bool showRequireGraph = false;

    // Parse arguments
    for (int i = argOffset; i < argc; ++i)
    {
        const char* currentArg = argv[i];

        if (strcmp(currentArg, "-h") == 0 || strcmp(currentArg, "--help") == 0)
        {
            reporter.reportOutput(COMPILE_HELP_STRING);
            return 0;
        }
        else if (strcmp(currentArg, "--output") == 0)
        {
            if (i + 1 >= argc)
            {
                reporter.reportError("Error: --output requires a path argument.");
                reporter.reportOutput(COMPILE_HELP_STRING);
                return 1;
            }
            outputPath = argv[++i];
        }
        else if (strcmp(currentArg, "--bundle-stats") == 0)
            bundleStats = true;
        else if (strcmp(currentArg, "--show-require-graph") == 0)
            showRequireGraph = true;
        else if (currentArg[0] == '-')
        {
            reporter.formatError("Error: Unrecognized option '%s' for 'compile' command.", currentArg);
            reporter.reportOutput(COMPILE_HELP_STRING);
            return 1;
        }
        else if (filePath.empty())
        {
            filePath = currentArg;
        }
        else
        {
            reporter.reportError("Error: Too many arguments for 'compile' command.");
            reporter.reportOutput(COMPILE_HELP_STRING);
            return 1;
        }
    }

    if (filePath.empty())
    {
        reporter.reportError("Error: No input file specified for 'compile' command.");
        reporter.reportOutput(COMPILE_HELP_STRING);
        return 1;
    }

    std::string absoluteEntryPoint;
    if (isAbsolutePath(filePath))
    {
        absoluteEntryPoint = filePath;
    }
    else
    {
        std::optional<std::string> cwd = getCurrentWorkingDirectory();
        if (!cwd)
        {
            reporter.reportError("Error: Failed to get current working directory.\n");
            return 1;
        }
        absoluteEntryPoint = normalizePath(joinPaths(*cwd, filePath));
    }

    // Set default output path if not specified
    if (outputPath.empty())
    {
        // Extract base name from input file (remove directory and extension)
        std::string baseName = filePath;

        // Remove directory path
        size_t lastSlash = baseName.find_last_of("/\\");
        if (lastSlash != std::string::npos)
            baseName = baseName.substr(lastSlash + 1);

        // Remove extension
        size_t lastDot = baseName.find_last_of('.');
        if (lastDot != std::string::npos)
            baseName = baseName.substr(0, lastDot);

        outputPath = baseName;
#ifdef _WIN32
        outputPath += ".exe";
#endif
    }

    // Perform static require trace
    StaticRequireTracer tracer{reporter};
    tracer.trace(absoluteEntryPoint);

    if (showRequireGraph)
        tracer.printRequireGraph();

    // Create payload and add all discovered files
    LuteExePayload payload{reporter};
    auto staticRequirePairs = tracer.getStaticRequirePairs();
    // Add file with absolute path for reading and rooted path for bundle
    // We don't want to leak your entire directory path in the bundle, so we
    // try to pick the lowest common ancestor and keep that as the root.
    for (const auto& [bundle, absolute] : staticRequirePairs)
    {
        payload.add(bundle, absolute);
    }

    // Add the discovered luaurc configuration
    payload.setLuauConfig(tracer.getLuaurcFiles());


    // Encode the payload
    reporter.reportOutput("Compiling and bundling bytecode...");
    std::optional<LuteEncodeResult> encodeResult = payload.encode();
    if (!encodeResult)
    {
        reporter.reportError("Error: Failed to encode bundle");
        return 1;
    }

    // Show bundle stats if requested
    if (bundleStats)
    {
        reporter.reportOutput("\nBundle Statistics:");
        reporter.formatOutput("\tFiles bundled: %zu", staticRequirePairs.size());
        reporter.formatOutput("\tUncompressed size: %zu bytes", encodeResult->uncompressedPayloadSizeBytes);
        reporter.formatOutput("\tCompressed size: %zu bytes", encodeResult->compressedPayloadSizeBytes);
        reporter.formatOutput(
            "\tSpace saved: %.2f%%",
            100.0 * (1.0 - (double)encodeResult->compressedPayloadSizeBytes / (double)encodeResult->uncompressedPayloadSizeBytes)
        );
        reporter.formatOutput(
            "\tCompression ratio: %.2f:1", (double)encodeResult->uncompressedPayloadSizeBytes / (double)encodeResult->compressedPayloadSizeBytes
        );
        reporter.formatOutput("\tTotal payload size: %zu bytes", encodeResult->bytesWritten);
        reporter.reportOutput("");
    }

    // Get current executable path
    std::string errorMsg;
    std::optional<std::string> exePath = process::getExecPath(&errorMsg);
    if (!exePath)
    {
        reporter.formatError("Error: Failed to get executable path: %s", errorMsg.c_str());
        return 1;
    }

    // Create the executable with embedded payload
    LuteExecutable executable{*exePath, reporter};
    if (!executable.create(outputPath, payload))
    {
        reporter.reportError("Error: Failed to create executable.");
        return 1;
    }

    reporter.formatOutput("Created executable '%s'", outputPath.c_str());
    return 0;
}

int handleCliCommand(CliCommandResult result, int program_argc, char** program_argv, LuteReporter& reporter)
{
    Runtime runtime;
    lua_State* L = setupCliState(runtime);

    std::string bytecode = Luau::compile(std::string(result.contents), copts());
    return runBytecode(runtime, bytecode, "@" + result.path, L, program_argc, program_argv, reporter) ? 0 : 1;
}

int cliMain(int argc, char** argv, LuteReporter& reporter)
{
    Luau::assertHandler() = assertionHandler;
    setLuauFlags();

    std::string err = "";

    LuteExecutable exe{argv[0], reporter};
    if (auto payload = exe.extract())
    {
        Runtime runtime;

        lua_State* GL = setupBundleState(runtime, payload->luauConfigFiles, payload->filePathToBytecode);
        std::string entryPoint = payload->entryPointPath;
        auto entryModule = payload->filePathToBytecode.find(entryPoint);
        if (entryModule != nullptr)
        {
            bool success = runBytecode(runtime, *entryModule, "@@bundle/" + entryPoint, GL, argc, argv, reporter);
            return success ? 0 : 1;
        }
    }

#ifdef _WIN32
    SetConsoleOutputCP(CP_UTF8);
#endif

    if (argc < 2)
    {
        // TODO: REPL?
        reporter.reportOutput(HELP_STRING);
        return 0;
    }

    const char* command = argv[1];
    int argOffset = 2;

    if (strcmp(command, "run") == 0)
    {
        return handleRunCommand(argc, argv, argOffset, reporter);
    }
    else if (strcmp(command, "check") == 0)
    {
        return handleCheckCommand(argc, argv, argOffset, reporter);
    }
    else if (strcmp(command, "compile") == 0)
    {
        return handleCompileCommand(argc, argv, argOffset, reporter);
    }
    else if (strcmp(command, "-h") == 0 || strcmp(command, "--help") == 0)
    {
        reporter.reportOutput(HELP_STRING);
        return 0;
    }
    else if (strcmp(command, "--version") == 0)
    {
        reporter.reportOutput(VERSION_STRING);
        return 0;
    }
    else if (std::optional<CliCommandResult> result = getCliCommand(command); result)
    {
        return handleCliCommand(*result, argc - argOffset, &argv[argOffset], reporter);
    }
    else
    {
        // Default to 'run' command
        argOffset = 1;
        return handleRunCommand(argc, argv, argOffset, reporter);
    }
}
