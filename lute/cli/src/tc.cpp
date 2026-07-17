#include "lute/tc.h"

#include "lute/configresolver.h"
#include "lute/tcmoduleresolver.h"

#include "Luau/BuiltinDefinitions.h"
#include "Luau/Error.h"
#include "Luau/FileUtils.h"
#include "Luau/Frontend.h"
#include "Luau/LuauConfig.h"

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
};

struct DefinitionExtractResult
{
    std::vector<DefinitionEntry> entries;
    std::string error;

    bool ok() const
    {
        return error.empty();
    }
};

static DefinitionExtractResult extractDefinitionEntries(const Luau::ConfigTable& configTable)
{
    if (!configTable.contains("lute"))
        return {};

    const Luau::ConfigTable* luteTable = configTable.find("lute")->get_if<Luau::ConfigTable>();
    if (!luteTable)
        return {{}, "configuration value for key \"lute\" must be a table"};

    if (!luteTable->contains("definitions"))
        return {};

    const Luau::ConfigTable* defsTable = (*luteTable).find("definitions")->get_if<Luau::ConfigTable>();
    if (!defsTable)
        return {{}, "configuration value for key \"lute.definitions\" must be a table"};

    std::vector<DefinitionEntry> entries;

    for (const auto& [k, v] : *defsTable)
    {
        const std::string* key = k.get_if<std::string>();
        if (!key)
            return {{}, "configuration keys in \"lute.definitions\" must be strings"};

        const std::string* value = v.get_if<std::string>();
        if (!value)
            return {{}, "configuration values in \"lute.definitions\" must be strings (file paths)"};

        entries.push_back({*key, *value});
    }

    return {std::move(entries), {}};
}

static int loadDefinitions(
    Luau::Frontend& frontend,
    const std::vector<DefinitionEntry>& entries,
    const std::string& configDir,
    LuteReporter& reporter
)
{
    int failures = 0;

    for (const DefinitionEntry& entry : entries)
    {
        std::string resolvedPath = normalizePath(joinPaths(configDir, entry.path));

        if (!isFile(resolvedPath))
        {
            reporter.formatError("Error: Definition file not found: %s\n", resolvedPath.c_str());
            failures++;
            continue;
        }

        std::optional<std::string> source = readFile(resolvedPath);
        if (!source)
        {
            reporter.formatError("Error: Failed to read definition file: %s\n", resolvedPath.c_str());
            failures++;
            continue;
        }

        std::string packageName = "@definitions/" + entry.name;

        Luau::LoadDefinitionFileResult result =
            frontend.loadDefinitionFile(frontend.globals, frontend.globals.globalScope, *source, packageName, false);

        if (!result.success)
        {
            reporter.formatError("Error: Failed to load definition file: %s\n", resolvedPath.c_str());

            for (const auto& parseError : result.parseResult.errors)
            {
                reporter.formatError(
                    "  %s:%d:%d: %s\n",
                    resolvedPath.c_str(),
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
                        resolvedPath.c_str(),
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

static std::optional<std::string> findProjectConfig()
{
    for (auto dir = getCurrentWorkingDirectory(); dir; dir = getParentPath(*dir))
    {
        std::string candidate = joinPaths(*dir, Luau::kLuauConfigName);
        if (isFile(candidate))
            return candidate;
    }
    return std::nullopt;
}

int typecheck(const std::vector<std::string>& sourceFilesInput, LuteReporter& reporter, std::optional<std::string> configPathOverride)
{
    std::vector<std::string> sourceFiles = processSourceFiles(sourceFilesInput);

    if (sourceFiles.empty())
    {
        reporter.reportError("Error: lute check expects a file to type check.\n\n");
        return 1;
    }

    std::vector<DefinitionEntry> definitionEntries;
    std::string configDir;

    std::optional<std::string> configPath = configPathOverride ? configPathOverride : findProjectConfig();
    if (configPath)
    {
        std::optional<std::string> parentDir = getParentPath(*configPath);
        if (parentDir)
            configDir = *parentDir;

        std::optional<std::string> configSource = readFile(*configPath);
        if (configSource)
        {
            std::string parseError;
            std::optional<Luau::ConfigTable> configTable = Luau::extractConfig(*configSource, {}, &parseError);

            if (!configTable)
            {
                reporter.formatError("Error parsing %s: %s\n", configPath->c_str(), parseError.c_str());
                return 1;
            }

            DefinitionExtractResult extractResult = extractDefinitionEntries(*configTable);
            if (!extractResult.ok())
            {
                reporter.formatError("Error in %s: %s\n", configPath->c_str(), extractResult.error.c_str());
                return 1;
            }

            definitionEntries = std::move(extractResult.entries);
        }
    }

    Luau::Mode mode = Luau::Mode::Strict;
    bool annotate = true;
    std::string basePath = "";

    Luau::FrontendOptions frontendOptions;
    frontendOptions.retainFullTypeGraphs = annotate;

    Luau::LuteTypeCheckModuleResolver fileResolver{reporter};
    Luau::LuteConfigResolver configResolver(mode);
    Luau::Frontend frontend(Luau::SolverMode::New, &fileResolver, &configResolver, frontendOptions);

    Luau::registerBuiltinGlobals(frontend, frontend.globals);

    if (!definitionEntries.empty())
    {
        int defFailures = loadDefinitions(frontend, definitionEntries, configDir, reporter);
        if (defFailures > 0)
        {
            Luau::freeze(frontend.globals.globalTypes);
            return 1;
        }
    }

    Luau::freeze(frontend.globals.globalTypes);

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
