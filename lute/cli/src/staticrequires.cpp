#include "lute/staticrequires.h"

#include "lute/modulepath.h"

#include "Luau/Ast.h"
#include "Luau/FileUtils.h"
#include "Luau/Parser.h"
#include "Luau/VecDeque.h"

#include <cstdio>

// AST visitor to extract require() calls
class RequireExtractor : public Luau::AstVisitor
{
public:
    std::vector<std::string> requirePaths;

    bool visit(Luau::AstExprCall* call) override
    {
        if (auto global = call->func->as<Luau::AstExprGlobal>())
        {
            if (global->name == "require" && call->args.size > 0)
            {
                if (auto str = call->args.data[0]->as<Luau::AstExprConstantString>())
                {
                    requirePaths.emplace_back(str->value.data, str->value.size);
                }
            }
        }
        return true;
    }
};

StaticRequireTracer::StaticRequireTracer(LuteReporter& reporter)
    : reporter(reporter)
{
}

std::vector<std::string> StaticRequireTracer::trace(const std::string& rootDirectory, const std::string& entryPoint)
{
    visited.clear();
    discovered.clear();
    requireGraph.clear();
    this->rootDirectory = rootDirectory;

    Luau::VecDeque<std::string> toProcess;
    toProcess.push_back(entryPoint);

    while (!toProcess.empty())
    {
        std::string filePath = toProcess.front();
        toProcess.pop_front();

        // Get normalized path for visited tracking
        std::string fullPath = joinPaths(rootDirectory, filePath);
        std::string absPath = normalizePath(fullPath);

        // Skip if already visited (handles circular dependencies)
        if (visited.contains(absPath))
            continue;

        visited.insert(absPath);
        std::optional<std::string> source = readFile(fullPath);
        if (!source)
        {
            reporter.formatError("Warning: Could not read file '%s'\n", fullPath.c_str());
            continue;
        }

        // Add to discovered list (use the relative path from rootDirectory)
        discovered.push_back(filePath);

        std::vector<std::string> requiresInFile = extractRequires(*source);

        std::vector<std::string> resolvedDeps;

        for (const auto& req : requiresInFile)
        {
            std::optional<std::string> resolvedPath = resolveRequire(filePath, req);
            if (resolvedPath)
            {
                toProcess.push_back(*resolvedPath);
                resolvedDeps.push_back(*resolvedPath);
            }
            else
            {
                // Skip warning for built-in libraries (@std and @lute)
                bool isBuiltinLibrary = req.rfind("@std/", 0) == 0 || req.rfind("@lute/", 0) == 0;
                if (!isBuiltinLibrary)
                {
                    reporter.formatError("Warning: Could not resolve require('%s') from '%s'\n", req.c_str(), filePath.c_str());
                }
            }
        }

        // Store the resolved dependencies in the graph
        requireGraph[filePath] = std::move(resolvedDeps);
    }

    return discovered;
}

std::vector<std::string> StaticRequireTracer::extractRequires(const std::string& source)
{
    Luau::Allocator allocator;
    Luau::AstNameTable names(allocator);

    Luau::ParseOptions options;
    Luau::ParseResult result = Luau::Parser::parse(source.c_str(), source.size(), names, allocator, options);

    if (result.errors.size() > 0)
    {
        // Even with parse errors, we can still try to extract requires
        // Parse errors might be from type errors or other issues that don't prevent require extraction
        // Should we do something here, or should it be best effort?
    }

    RequireExtractor extractor;
    result.root->visit(&extractor);

    return extractor.requirePaths;
}

std::optional<std::string> StaticRequireTracer::resolveRequire(const std::string& requirer, const std::string& required)
{
    // Get the directory containing the requiring file (relative to rootDirectory)
    std::string requirerDir;
    size_t lastSlash = requirer.find_last_of("/\\");
    if (lastSlash != std::string::npos)
    {
        requirerDir = requirer.substr(0, lastSlash);
    }
    else
    {
        requirerDir = "";
    }

    // Helper functions for ModulePath - paths are relative to rootDirectory
    auto isFileFunc = [this](const std::string& path) -> bool
    {
        std::string fullPath = joinPaths(rootDirectory, path);
        return isFile(fullPath);
    };

    auto isDir = [this](const std::string& path) -> bool
    {
        std::string fullPath = joinPaths(rootDirectory, path);
        return isDirectory(fullPath);
    };

    // Create a ModulePath with root as rootDirectory, starting at requirer's directory
    // This allows us to navigate up with .. beyond requirerDir, but not beyond rootDirectory
    std::optional<ModulePath> modulePath = ModulePath::create(
        "",          // Root is empty (relative path base)
        requirerDir, // Start at the requirer's directory
        isFileFunc,
        isDir
    );

    if (!modulePath)
        return std::nullopt;

    // Navigate according to the require path
    // Split require path by '/' and navigate
    std::string reqPath = required;
    size_t pos = 0;

    while (pos < reqPath.size())
    {
        size_t nextSlash = reqPath.find('/', pos);
        std::string component;

        if (nextSlash == std::string::npos)
        {
            component = reqPath.substr(pos);
            pos = reqPath.size();
        }
        else
        {
            component = reqPath.substr(pos, nextSlash - pos);
            pos = nextSlash + 1;
        }

        if (component.empty() || component == ".")
            continue;

        if (component == "..")
        {
            if (modulePath->toParent() != NavigationStatus::Success)
                return std::nullopt;
        }
        else
        {
            if (modulePath->toChild(component) != NavigationStatus::Success)
                return std::nullopt;
        }
    }

    // Get the resolved path (relative to rootDirectory)
    ResolvedRealPath resolved = modulePath->getRealPath();
    if (resolved.status != NavigationStatus::Success)
        return std::nullopt;

    // Strip leading slash if present (occurs when root is empty)
    std::string result = resolved.realPath;
    if (!result.empty() && result[0] == '/')
        result = result.substr(1);

    return result;
}

void StaticRequireTracer::printRequireGraph() const
{
    printf("\nRequire dependency graph:\n");
    for (const auto& [file, deps] : requireGraph)
    {
        printf("\t%s\n", file.c_str());
        for (const auto& dep : deps)
        {
            printf("\t\t -> %s\n", dep.c_str());
        }

        if (deps.empty())
        {
            printf("\t\t(no dependencies)\n");
        }
    }
    printf("\n");
}
