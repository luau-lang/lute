#include "lute/tc.h"

#include "lute/configresolver.h"
#include "lute/moduleresolver.h"

#include "Luau/BuiltinDefinitions.h"
#include "Luau/Error.h"
#include "Luau/FileUtils.h"
#include "Luau/Frontend.h"

static const std::string kLuteDefinitions = R"LUTE_TYPES(
-- Net api
declare net: {
    get: (string) -> string,
    getAsync: (string) -> string,
}
-- fs api
declare class file end
declare fs: {
 -- probably not the correct sig
    open: (string, "r" | "w" | "a" | "r+" | "w+") -> file,
    close: (file) -> (),
    read: (file) -> string,
    write: (file, string) -> (),
 -- is this right? I feel like we want a promise type here
    readasync : (string) -> string,
}

-- globals
declare function spawn(path: string): any

)LUTE_TYPES";

struct LuteFileResolver : Luau::LuteModuleResolver
{
    std::optional<Luau::SourceCode> readSource(const Luau::ModuleName& name) override
    {
        Luau::SourceCode::Type sourceType;
        std::optional<std::string> source = std::nullopt;

        // If the module name is "-", then read source from stdin
        if (name == "-")
        {
            source = readStdin();
            sourceType = Luau::SourceCode::Script;
        }
        else
        {
            source = readFile(name);
            sourceType = Luau::SourceCode::Module;
        }

        if (!source)
            return std::nullopt;

        return Luau::SourceCode{*source, sourceType};
    }

    std::string getHumanReadableModuleName(const Luau::ModuleName& name) const override
    {
        if (name == "-")
            return "stdin";
        return name;
    }
};

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

int typecheck(const std::vector<std::string>& sourceFilesInput, LuteReporter& reporter)
{
    std::vector<std::string> sourceFiles = processSourceFiles(sourceFilesInput);

    if (sourceFiles.empty())
    {
        reporter.reportError("Error: lute check expects a file to type check.\n\n");
        return 1;
    }

    Luau::Mode mode = Luau::Mode::Strict;
    bool annotate = true;
    std::string basePath = "";

    Luau::FrontendOptions frontendOptions;
    frontendOptions.retainFullTypeGraphs = annotate;
    frontendOptions.runLintChecks = true;

    LuteFileResolver fileResolver;
    Luau::LuteConfigResolver configResolver(mode);
    Luau::Frontend frontend(&fileResolver, &configResolver, frontendOptions);
    frontend.setLuauSolverMode(Luau::SolverMode::New);

    Luau::registerBuiltinGlobals(frontend, frontend.globals);
    Luau::LoadDefinitionFileResult loadResult =
        frontend.loadDefinitionFile(frontend.globals, frontend.globals.globalScope, kLuteDefinitions, "@luau", false, false);
    LUAU_ASSERT(loadResult.success);
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
