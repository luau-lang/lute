#include "lute/climain.h"

#include "lute/clicommands.h"
#include "lute/compile.h"
#include "lute/fileutils.h"
#include "lute/luauflags.h"
#include "lute/modulepath.h"
#include "lute/options.h"
#include "lute/packagerun.h"
#include "lute/process.h"
#include "lute/profiler.h"
#include "lute/ref.h"
#include "lute/reporter.h"
#include "lute/requiresetup.h"
#include "lute/runtime.h"
#include "lute/staticrequires.h"
#include "lute/tc.h"
#include "lute/version.h"

#include "Luau/CodeGen.h"
#include "Luau/Common.h"
#include "Luau/Compiler.h"
#include "Luau/DenseHash.h"
#include "Luau/FileUtils.h"

#include "lua.h"
#include "lualib.h"

#include <chrono>
#include <cstdlib>
#include <ctime>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#ifdef _WIN32
#include <Windows.h>
#endif

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
	--profile               Enable profiling for the script.
	--profile-output <path> Output file for the profile (default: <datetime>_<filename>.json).
	--frequency <Hz>        Profiler sampling frequency in Hz (default: 10000).
	-h, --help              Display this usage message.
)";

static const char* PKGRUN_HELP_STRING = R"(Usage: lute pkg run <script.luau> [args...]

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
    LuteReporter& reporter,
    std::optional<ProfileOptions> profileOptions
)
{
    // module needs to run in a new thread, isolated from the rest
    lua_State* L = lua_newthread(GL);

    if (profileOptions)
        profilerStart(L, profileOptions->frequency);

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

    runtime.args.clear();
    for (int i = 0; i < program_argc; ++i)
        runtime.args.emplace_back(program_argv[i]);

    runtime.GL = GL;
    runtime.runningThreads.push_back({true, getRefForThread(L), program_argc});

    lua_pop(GL, 1);

    bool b = runtime.runToCompletion();
    if (profileOptions)
    {
        profilerStop();
        profilerDump(profileOptions->filename.c_str(), reporter);
    }

    return b;
}

static bool runFile(
    Runtime& runtime,
    const char* name,
    lua_State* GL,
    int program_argc,
    char** program_argv,
    LuteReporter& reporter,
    std::optional<ProfileOptions> profileOptions = std::nullopt
)
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

    return runBytecode(runtime, bytecode, chunkname, GL, program_argc, program_argv, reporter, profileOptions);
}

static int assertionHandler(const char* expr, const char* file, int line, const char* function)
{
    printf("%s(%d): ASSERTION FAILED: %s\n", file, line, expr);
    return 1;
}

// Returns whether the filePath could be resolved to a valid file path, and a string containing either the valid path or an error message
static std::pair<bool, std::string> getWithRequireByStringSemantics(std::string filePath)
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
        return {false, "Could not initialize ModulePath instance."};

    ResolvedRealPath resolved = mp->getRealPath();

    std::pair<bool, std::string> result;
    switch (resolved.status)
    {
    case NavigationStatus::Success:
        if (resolved.type == ResolvedRealPath::PathType::File)
            result = {true, resolved.realPath};
        else
            result = {false, "Path is a directory, not a file."};
        break;
    case NavigationStatus::Ambiguous:
        result = {false, "Unable to tell whether path is a file or directory. Is there a same-named file or directory?"};
        break;
    case NavigationStatus::NotFound:
        result = {false, "File or directory not found."};
        break;
    }

    return result;
};

// Returns whether the filePath could be resolved to a valid file path, and a string containing either the valid path or an error message
static std::pair<bool, std::string> getValidPath(std::string filePath)
{
    auto [ok, res] = getWithRequireByStringSemantics(filePath);
    if (ok)
        return {true, res};

    // Only fallback to checking .lute/* if the original path has no extension.
    if (filePath.find('.') != std::string::npos)
        return {false, res};

    const std::array<std::string, 4> fallbackPaths = {
        joinPaths(".lute", filePath + ".lua"),
        joinPaths(".lute", filePath + ".luau"),
        joinPaths(joinPaths(".lute", filePath), "init.lua"),
        joinPaths(joinPaths(".lute", filePath), "init.luau"),
    };

    for (std::optional<std::string> currentPath = getCurrentWorkingDirectory(); currentPath; currentPath = getParentPath(*currentPath))
    {
        for (const std::string& fallbackPath : fallbackPaths)
        {
            const std::string commandPath = joinPaths(*currentPath, fallbackPath);
            if (isFile(commandPath))
                return {true, commandPath};
        }
    }

    return {false, res};
}

int handleRunCommand(int argc, char** argv, int argOffset, bool packageAwareness, LuteReporter& reporter)
{
    std::string command = packageAwareness ? "pkg run" : "run";
    std::string filePath;
    int program_argc = 0;
    bool enableProfiling = false;
    ProfileOptions profileOpts;
    bool hasProfileOutputArg = false;
    bool hasProfileFreqArg = false;
    char** program_argv = nullptr;

    for (int i = argOffset; i < argc; ++i)
    {
        const char* currentArg = argv[i];

        if (strcmp(currentArg, "-h") == 0 || strcmp(currentArg, "--help") == 0)
        {
            reporter.reportOutput(packageAwareness ? PKGRUN_HELP_STRING : RUN_HELP_STRING);
            return 0;
        }
        else if (strcmp(currentArg, "--profile") == 0)
        {
            enableProfiling = true;
        }
        else if (strcmp(currentArg, "--profile-output") == 0)
        {
            if (i + 1 >= argc)
            {
                reporter.reportError("Error: --profile-output requires a path argument.");
                reporter.reportOutput(packageAwareness ? PKGRUN_HELP_STRING : RUN_HELP_STRING);
                return 1;
            }
            profileOpts.filename = argv[++i];
            hasProfileOutputArg = true;
        }
        else if (strcmp(currentArg, "--frequency") == 0)
        {
            if (i + 1 >= argc)
            {
                reporter.reportError("Error: --frequency requires a value argument.");
                reporter.reportOutput(packageAwareness ? PKGRUN_HELP_STRING : RUN_HELP_STRING);
                return 1;
            }
            profileOpts.frequency = std::stoi(argv[++i]);
            hasProfileFreqArg = true;
        }
        else if (currentArg[0] == '-')
        {
            reporter.formatError("Error: Unrecognized option '%s' for '%s' command.", currentArg, command.c_str());
            reporter.reportOutput(packageAwareness ? PKGRUN_HELP_STRING : RUN_HELP_STRING);
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
        reporter.formatError("Error: No file specified for '%s' command.", command.c_str());
        reporter.reportOutput(packageAwareness ? PKGRUN_HELP_STRING : RUN_HELP_STRING);
        return 1;
    }

    auto [ok, validPath] = getValidPath(filePath);
    if (!ok)
    {
        reporter.formatError("Error while resolving filepath '%s': %s", filePath.c_str(), validPath.c_str());
        return 1;
    }

    std::optional<ProfileOptions> profileOptions;
    if (enableProfiling)
    {
        if (profileOpts.filename.empty())
        {
            auto now = std::chrono::system_clock::now();
            std::time_t nowTime = std::chrono::system_clock::to_time_t(now);
            std::tm* localTime = std::localtime(&nowTime);

            char dateTimeStr[20];
            std::strftime(dateTimeStr, sizeof(dateTimeStr), "%Y-%m-%d_%H-%M-%S", localTime);

            std::string baseName = Lute::getFilenameWithoutExtension(filePath);
            profileOpts.filename = std::string(dateTimeStr) + "_" + baseName + ".json";
        }

        profileOptions.emplace(profileOpts);
    }
    else if (hasProfileOutputArg || hasProfileFreqArg)
    {
        reporter.reportError("You passed --profile-output or --frequency without passing --profile.");
        return 1;
    }

    Runtime runtime{reporter};
    lua_State* L;

    if (packageAwareness)
    {
        if (!isAbsolutePath(validPath))
        {
            std::optional<std::string> cwd = getCurrentWorkingDirectory();
            if (!cwd)
            {
                reporter.reportError("Error: Failed to get current working directory.\n");
                return 1;
            }
            validPath = normalizePath(joinPaths(*cwd, validPath));
        }

        std::optional<std::string> lockfile = getAbsolutePathToNearestLockfile(validPath);
        if (!lockfile)
        {
            reporter.formatError("Error: No loom.lock file found for '%s'", validPath.c_str());
            return 1;
        }

        auto [directDependencies, allDependencies] = getDependenciesFromLockfile(*lockfile);
        L = setupPkgRunState(runtime, std::move(directDependencies), std::move(allDependencies));
    }
    else
    {
        L = setupRunState(runtime);
    }

    bool success = runFile(runtime, validPath.c_str(), L, program_argc, program_argv, reporter, profileOptions);
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
    std::optional<std::string> exePath = Process::getExecPath(&errorMsg);
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

void setupVersionLibrary(lua_State* L)
{
    lua_checkstack(L, 2);

    lua_createtable(L, 0, 3);

    lua_pushstring(L, LUTE_VERSION);
    lua_setfield(L, -2, "version");

    lua_pushstring(L, LUTE_VERSION_SUFFIX);
    lua_setfield(L, -2, "versionSuffix");

    lua_pushstring(L, LUTE_VERSION_FULL);
    lua_setfield(L, -2, "versionFull");

    lua_setglobal(L, "version");
}

int handleCliCommand(CliCommandResult result, int program_argc, char** program_argv, LuteReporter& reporter)
{
    Runtime runtime{reporter};
    lua_State* L = setupCliCommandState(runtime, setupVersionLibrary);

    std::string bytecode = Luau::compile(std::string(result.contents), copts());
    return runBytecode(runtime, bytecode, "@" + result.path, L, program_argc, program_argv, reporter) ? 0 : 1;
}

int cliMain(int argc, char** argv, LuteReporter& reporter)
{
    Luau::assertHandler() = assertionHandler;
    setLuauFlags();

    if (const char* unbuffered = std::getenv("LUTE_UNBUFFERED"); unbuffered && std::string_view(unbuffered) == "1")
    {
        setvbuf(stdout, nullptr, _IONBF, 0);
        setvbuf(stderr, nullptr, _IONBF, 0);
    }

    std::string err = "";

    LuteExecutable exe{argv[0], reporter};
    if (auto payload = exe.extract())
    {
        Runtime runtime{reporter};

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
    const char* subcommand = argc >= 3 ? argv[2] : nullptr;
    int argOffset = 2;

    if (strcmp(command, "run") == 0)
    {
        return handleRunCommand(argc, argv, argOffset, /* packageAwareness = */ false, reporter);
    }
    else if (strcmp(command, "pkg") == 0 && subcommand && strcmp(subcommand, "run") == 0)
    {
        return handleRunCommand(argc, argv, argOffset + 1, /* packageAwareness = */ true, reporter);
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
        return handleRunCommand(argc, argv, argOffset, /* packageAwareness = */ false, reporter);
    }
}
