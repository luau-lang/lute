#include "lute/tc.h"

#include "lute/clicommands.h"
#include "lute/configresolver.h"
#include "lute/requiresetup.h"
#include "lute/result.h"
#include "lute/runtime.h"
#include "lute/tcmoduleresolver.h"

#include "Luau/BuiltinDefinitions.h"
#include "Luau/Compiler.h"
#include "Luau/Error.h"
#include "Luau/FileUtils.h"
#include "Luau/Frontend.h"
#include "Luau/LuauConfig.h"

#include "lua.h"

static void report(const char* name, const Luau::Location& loc, const char* type, const char* message, LuteReporter& reporter)
{
    // fprintf(stderr, "%s(%d,%d): %s: %s\n", name, loc.begin.line + 1, loc.begin.column + 1, type, message);
    int columnEnd = (loc.begin.line == loc.end.line) ? loc.end.column : 100;

    // Use stdout to match luacheck behavior
    reporter.formatOutput("%s:%d:%d-%d: (W0) %s: %s\n", name, loc.begin.line + 1, loc.begin.column + 1, columnEnd, type, message);
}

static void reportError(const Luau::Frontend& frontend, const Luau::TypeError& error, LuteReporter& reporter)
{
    std::string humanReadableName = frontend.fileResolver->getHumanReadableModuleName(error.moduleName);

    if (const Luau::SyntaxError* syntaxError = Luau::get_if<Luau::SyntaxError>(&error.data))
        report(humanReadableName.c_str(), error.location, "SyntaxError", syntaxError->message.c_str(), reporter);
    else
        report(
            humanReadableName.c_str(),
            error.location,
            "TypeError",
            Luau::toString(error, Luau::TypeErrorToStringOptions{frontend.fileResolver}).c_str(),
            reporter
        );
}

static void reportWarning(const char* name, const Luau::LintWarning& warning, LuteReporter& reporter)
{
    report(name, warning.location, Luau::LintWarning::getName(warning.code), warning.text.c_str(), reporter);
}

static bool reportModuleResult(Luau::Frontend& frontend, const Luau::ModuleName& name, bool annotate, LuteReporter& reporter)
{
    std::optional<Luau::CheckResult> cr = frontend.getCheckResult(name, false);

    if (!cr)
    {
        reporter.formatError("Failed to find result for %s\n", name.c_str());
        return false;
    }

    if (!frontend.getSourceModule(name))
    {
        reporter.formatError("Error opening %s\n", name.c_str());
        return false;
    }

    for (auto& error : cr->errors)
        reportError(frontend, error, reporter);

    std::string humanReadableName = frontend.fileResolver->getHumanReadableModuleName(name);
    for (auto& error : cr->lintResult.errors)
        reportWarning(humanReadableName.c_str(), error, reporter);
    for (auto& warning : cr->lintResult.warnings)
        reportWarning(humanReadableName.c_str(), warning, reporter);

    return cr->errors.empty() && cr->lintResult.errors.empty();
}

static std::string getExtension(const std::string& path)
{
    size_t dot = path.find_last_of(".\\/");

    if (dot == std::string::npos || path[dot] != '.')
        return "";

    return path.substr(dot);
}

std::vector<std::string> processSourceFiles(const std::vector<std::string>& sourceFilesInput)
{
    std::vector<std::string> files;

    for (const auto& path : sourceFilesInput)
    {
        std::string normalized = normalizePath(path);

        if (isDirectory(normalized))
        {
            traverseDirectory(
                normalized,
                [&](const std::string& name)
                {
                    std::string ext = getExtension(name);

                    if (ext == ".lua" || ext == ".luau")
                        files.push_back(name);
                }
            );
        }
        else
        {
            files.push_back(normalized);
        }
    }


    return files;
}

struct DefinitionEntry
{
    std::string name;
    std::string path;

    DefinitionEntry(std::string name, std::string path)
        : name(std::move(name))
        , path(std::move(path))
    {
    }
};

static Lute::Result<const Luau::ConfigTable*> getCheckConfig(const Luau::ConfigTable& configTable)
{
    using Result = Lute::Result<const Luau::ConfigTable*>;

    auto* luteValue = configTable.find("lute");
    if (!luteValue)
        return Result::success(nullptr);

    auto* luteTable = luteValue->get_if<Luau::ConfigTable>();
    if (!luteTable)
        return Result::failure("configuration value for key \"lute\" must be a table");

    auto* checkValue = luteTable->find("check");
    if (!checkValue)
        return Result::success(nullptr);

    auto* checkTable = checkValue->get_if<Luau::ConfigTable>();
    if (!checkTable)
        return Result::failure("configuration value for key \"lute.check\" must be a table");

    return Result::success(checkTable);
}

static Lute::Result<std::vector<DefinitionEntry>> extractDefinitionEntries(const Luau::ConfigTable& configTable, const std::string& configDir)
{
    using Result = Lute::Result<std::vector<DefinitionEntry>>;

    auto settings = getCheckConfig(configTable);
    if (!settings.ok())
        return Result::failure(settings.error());
    const Luau::ConfigTable* checkTable = settings.value();
    if (!checkTable)
        return Result::success({});

    auto* defsValue = checkTable->find("definitions");
    if (!defsValue)
        return Result::success({});

    auto* defsTable = defsValue->get_if<Luau::ConfigTable>();
    if (!defsTable)
        return Result::failure("configuration value for key \"lute.check.definitions\" must be a table");

    std::vector<DefinitionEntry> entries;

    for (const auto& [k, v] : *defsTable)
    {
        const std::string* key = k.get_if<std::string>();
        if (!key)
            return Result::failure("configuration keys in \"lute.check.definitions\" must be strings");

        const std::string* value = v.get_if<std::string>();
        if (!value)
            return Result::failure("configuration values in \"lute.check.definitions\" must be strings (file paths)");

        entries.emplace_back(*key, normalizePath(joinPaths(configDir, *value)));
    }

    return Result::success(std::move(entries));
}

static Lute::Result<std::vector<DefinitionEntry>> findDefinitions(const std::optional<std::string>& configPathOverride)
{
    using Result = Lute::Result<std::vector<DefinitionEntry>>;

    if (configPathOverride)
    {
        std::optional<std::string> contents = readFile(*configPathOverride);
        if (!contents)
            return Result::success({});

        std::string parseError;
        std::optional<Luau::ConfigTable> configTable = Luau::extractConfig(*contents, {}, &parseError);
        if (!configTable)
            return Result::failure(std::move(parseError));

        std::optional<std::string> configDir = getParentPath(*configPathOverride);
        return extractDefinitionEntries(*configTable, configDir.value_or(""));
    }

    for (auto dir = getCurrentWorkingDirectory(); dir; dir = getParentPath(*dir))
    {
        std::string candidate = joinPaths(*dir, Luau::kLuauConfigName);
        if (!isFile(candidate))
            continue;

        std::optional<std::string> contents = readFile(candidate);
        if (!contents)
            continue;

        std::string parseError;
        std::optional<Luau::ConfigTable> configTable = Luau::extractConfig(*contents, {}, &parseError);
        if (!configTable)
            return Result::failure(std::move(parseError));

        auto result = extractDefinitionEntries(*configTable, *dir);
        if (!result.ok())
            return Result::failure(result.error());
        if (!result.value().empty())
            return result;
    }
    return Result::success({});
}

static int loadDefinitions(const std::vector<DefinitionEntry>& entries, Luau::Frontend& frontend, LuteReporter& reporter)
{
    int failures = 0;

    for (const DefinitionEntry& entry : entries)
    {
        if (!isFile(entry.path))
        {
            reporter.formatError("Error: Definition file not found: %s\n", entry.path.c_str());
            failures++;
            continue;
        }

        std::optional<std::string> source = readFile(entry.path);
        if (!source)
        {
            reporter.formatError("Error: Failed to read definition file: %s\n", entry.path.c_str());
            failures++;
            continue;
        }

        std::string packageName = "@definitions/" + entry.name;

        Luau::LoadDefinitionFileResult result =
            frontend.loadDefinitionFile(frontend.globals, frontend.globals.globalScope, *source, packageName, false);

        if (!result.success)
        {
            reporter.formatError("Error: Failed to load definition file: %s\n", entry.path.c_str());

            for (const auto& parseError : result.parseResult.errors)
            {
                reporter.formatError(
                    "  %s:%d:%d: %s\n",
                    entry.path.c_str(),
                    parseError.getLocation().begin.line + 1,
                    parseError.getLocation().begin.column + 1,
                    parseError.getMessage().c_str()
                );
            }

            if (result.module)
            {
                for (const auto& error : result.module->errors)
                {
                    reporter.formatError(
                        "  %s:%d:%d: %s\n",
                        entry.path.c_str(),
                        error.location.begin.line + 1,
                        error.location.begin.column + 1,
                        Luau::toString(error).c_str()
                    );
                }
            }

            failures++;
        }
    }

    return failures;
}

static int loadTypeDefinitions(Luau::Frontend& frontend, LuteReporter& reporter, std::optional<std::string> configPathOverride)
{
    auto definitions = findDefinitions(configPathOverride);
    if (!definitions.ok())
    {
        reporter.formatError("%s\n", definitions.error().c_str());
        return 1;
    }

    const std::vector<DefinitionEntry>& entries = definitions.value();
    if (!entries.empty())
    {
        if (int defFailures = loadDefinitions(entries, frontend, reporter); defFailures > 0)
            return 1;
    }

    return 0;
}

static bool applyIgnorePatterns(
    const Luau::ConfigTable& patterns,
    const std::string& configDir,
    std::string_view filterSource,
    std::vector<std::string>& sourceFiles,
    LuteReporter& reporter
)
{
    Runtime runtime{reporter};
    lua_State* state = setupCliCommandState(runtime);
    const std::string bytecode = Luau::compile(std::string(filterSource));
    if (luau_load(state, "@@cli/lib/checkIgnores.luau", bytecode.data(), bytecode.size(), 0) == 0)
    {
        lua_pushstring(state, configDir.c_str());
        lua_createtable(state, int(patterns.size()), 0);
        for (size_t index = 1; index <= patterns.size(); ++index)
        {
            const auto* entry = patterns.find(double(index));
            const auto* pattern = entry ? entry->get_if<std::string>() : nullptr;
            if (!pattern)
            {
                reporter.reportError("configuration value for key \"lute.check.ignores\" must be an array of strings\n");
                return false;
            }
            lua_pushlstring(state, pattern->data(), pattern->size());
            lua_rawseti(state, -2, int(index));
        }

        lua_createtable(state, int(sourceFiles.size()), 0);
        for (size_t index = 0; index < sourceFiles.size(); ++index)
        {
            lua_pushstring(state, sourceFiles[index].c_str());
            lua_rawseti(state, -2, int(index + 1));
        }

        if (lua_pcall(state, 3, 1, 0) == 0)
        {
            sourceFiles.clear();
            for (int index = 1, size = lua_objlen(state, -1); index <= size; ++index)
            {
                lua_rawgeti(state, -1, index);
                sourceFiles.emplace_back(lua_tostring(state, -1));
                lua_pop(state, 1);
            }
            return true;
        }
    }

    const char* error = lua_tostring(state, -1);
    reporter.formatError("Failed to apply lute.check.ignores: %s\n", error ? error : "unknown error");
    return false;
}

static bool filterIgnoredSourceFiles(
    std::vector<std::string>& sourceFiles,
    LuteReporter& reporter,
    const std::optional<std::string>& configPathOverride
)
{
    const CliModuleResult filter = getCliModule("@cli/lib/checkIgnores.luau");
    if (filter.type != CliModuleType::Module)
        return true;

    auto dir = configPathOverride ? std::optional{getParentPath(*configPathOverride).value_or("")} : getCurrentWorkingDirectory();
    for (; dir; dir = configPathOverride ? std::nullopt : getParentPath(*dir))
    {
        const std::string candidate = configPathOverride ? *configPathOverride : joinPaths(*dir, Luau::kLuauConfigName);
        const auto contents = readFile(candidate);
        if (!contents)
            continue;

        std::string parseError;
        const auto config = Luau::extractConfig(*contents, {}, &parseError);
        if (!config)
        {
            reporter.formatError("%s\n", parseError.c_str());
            return false;
        }

        const auto settings = getCheckConfig(*config);
        if (!settings.ok())
        {
            reporter.formatError("%s\n", settings.error().c_str());
            return false;
        }

        const auto* check = settings.value();
        const auto* ignores = check ? check->find("ignores") : nullptr;
        if (!ignores)
            continue;

        const auto* patterns = ignores->get_if<Luau::ConfigTable>();
        if (!patterns)
        {
            reporter.reportError("configuration value for key \"lute.check.ignores\" must be an array of strings\n");
            return false;
        }

        return patterns->size() == 0 || applyIgnorePatterns(*patterns, *dir, filter.contents, sourceFiles, reporter);
    }

    return true;
}

int typecheck(const std::vector<std::string>& sourceFilesInput, LuteReporter& reporter, std::optional<std::string> configPathOverride)
{
    std::vector<std::string> sourceFiles = processSourceFiles(sourceFilesInput);

    if (sourceFiles.empty())
    {
        reporter.reportError("Error: lute check expects a file to type check.\n\n");
        return 1;
    }

    if (!filterIgnoredSourceFiles(sourceFiles, reporter, configPathOverride))
        return 1;
    if (sourceFiles.empty())
        return 0;

    Luau::Mode mode = Luau::Mode::Strict;
    bool annotate = true;
    std::string basePath = "";

    Luau::FrontendOptions frontendOptions;
    frontendOptions.retainFullTypeGraphs = annotate;

    Luau::LuteTypeCheckModuleResolver fileResolver{reporter};
    Luau::LuteConfigResolver configResolver(mode);
    Luau::Frontend frontend(Luau::SolverMode::New, &fileResolver, &configResolver, frontendOptions);

    Luau::registerBuiltinGlobals(frontend, frontend.globals);
    int definitionFailures = loadTypeDefinitions(frontend, reporter, configPathOverride);
    Luau::freeze(frontend.globals.globalTypes);

    if (definitionFailures > 0)
        return 1;

    for (const std::string& path : sourceFiles)
        frontend.queueModuleCheck(path);

    std::vector<Luau::ModuleName> checkedModules;
    try
    {
        checkedModules = frontend.checkQueuedModules(std::nullopt);
    }
    catch (const Luau::InternalCompilerError& ice)
    {
        Luau::Location location = ice.location ? *ice.location : Luau::Location();

        std::string moduleName = ice.moduleName ? *ice.moduleName : "<unknown module>";
        std::string humanReadableName = frontend.fileResolver->getHumanReadableModuleName(moduleName);

        Luau::TypeError error(location, moduleName, Luau::InternalError{ice.message});
        report(
            humanReadableName.c_str(),
            location,
            "InternalCompilerError",
            Luau::toString(error, Luau::TypeErrorToStringOptions{frontend.fileResolver}).c_str(),
            reporter
        );
        return 1;
    }

    int failed = 0;

    for (const Luau::ModuleName& name : checkedModules)
        failed += !reportModuleResult(frontend, name, annotate, reporter);

    if (!configResolver.configErrors.empty())
    {
        failed += int(configResolver.configErrors.size());

        for (const auto& pair : configResolver.configErrors)
            reporter.formatError("%s: %s\n", pair.first.c_str(), pair.second.c_str());
    }

    return failed ? 1 : 0;
}
