#include "lute/staticrequires.h"

#include "lute/modulepath.h"
#include "lute/resolverequire.h"
#include "lute/staticrequires.h"

#include "Luau/Ast.h"
#include "Luau/Config.h"
#include "Luau/FileUtils.h"
#include "Luau/Parser.h"
#include "Luau/VecDeque.h"

#include <algorithm>
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

void StaticRequireTracer::trace(const std::string& entryPoint)
{
    visited.clear();
    discovered.clear();
    requireGraph.clear();
    luaurcFiles.clear();

    if (!isAbsolutePath(entryPoint))
    {
        fprintf(stderr, "Error: %s isn't an absolute path\n", entryPoint.c_str());
        return;
    }

    // // Calculate the entry point directory - we should not look for .luaurc files beyond this directory
    // std::string entryPointDir = entryPoint;
    // size_t lastSlash = entryPointDir.find_last_of("/\\");
    // if (lastSlash != std::string::npos)
    // {
    //     entryPointDir = entryPointDir.substr(0, lastSlash);
    // }
    // else
    // {
    //     entryPointDir = "";
    // }

    // Temporary set to collect absolute paths to .luaurc files
    Luau::DenseHashSet<std::string> luaurcAbsolutePaths{""};

    Luau::VecDeque<std::string> toProcess;
    toProcess.push_back(entryPoint);

    while (!toProcess.empty())
    {
        std::string filePath = toProcess.front();
        toProcess.pop_front();

        // Skip if already visited (handles circular dependencies)
        if (visited.contains(filePath))
            continue;

        visited.insert(filePath);
        std::optional<std::string> source = readFile(filePath);
        if (!source)
        {
            reporter.formatError("Warning: Could not read file '%s'\n", filePath.c_str());
            continue;
        }

        // Add to discovered list (use the relative path from rootDirectory)
        discovered.push_back(filePath);

        // Discover .luaurc files in this file's directory tree
        std::string dir = filePath;
        size_t lastSlash = dir.find_last_of("/\\");
        if (lastSlash != std::string::npos)
        {
            dir = dir.substr(0, lastSlash);

            // Walk up the directory tree looking for .luaurc files, but stop at the entry point directory
            while (!dir.empty())
            {
                std::string luaurcPath = dir + "/" + Luau::kConfigName;
                if (isFile(luaurcPath))
                {
                    luaurcAbsolutePaths.insert(luaurcPath);
                    break;
                }

                // // Stop if we've reached the entry point directory
                // if (dir == entryPointDir)
                //     break;

                // Move to parent directory
                size_t parentSlash = dir.find_last_of("/\\");
                if (parentSlash == std::string::npos || parentSlash == 0)
                    break;
                dir = dir.substr(0, parentSlash);
            }
        }

        std::vector<std::string> requiresInFile = extractRequires(*source);

        std::vector<std::string> resolvedDeps;

        for (const auto& req : requiresInFile)
        {
            // Skip warning for built-in libraries (@std and @lute)
            // The new and improved requireResolver is really good - it'll even handle std/lute aliases that we've built in.
            // For now, we can just explicitly skip these, since they are provided by the runtime
            if (req.find("@std/") == 0 || req.find("@lute/") == 0)
                continue;
            std::string err = "";
            std::optional<std::string> resolvedPath = ::resolveRequire(req, "@" + filePath, &err);

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
                    reporter.formatError("Warning: Could not resolve require('%s') from '%s'\n", req.c_str(), filePath.c_str());
                if (!err.empty())
                    reporter.formatError("Warning: Could not resolve require('%s') from '%s':\n\t%s\n", req.c_str(), filePath.c_str(), err.c_str());
            }
        }

        // Store the resolved dependencies in the graph
        requireGraph[filePath] = std::move(resolvedDeps);
    }
    
    // Include .luaurc files in the lowest common root calculation
    std::vector<std::string> allPaths = discovered;
    for (const auto& luaurcPath : luaurcAbsolutePaths)
    {
        allPaths.push_back(luaurcPath);
    }
    
    lowestCommonRoot = findLowestCommonRoot(allPaths);

    // Convert absolute .luaurc paths to LCR-relative .luaurc paths and read their content
    size_t commonRootLen = lowestCommonRoot.empty() ? 0 : lowestCommonRoot.length() + 1; // +1 for the trailing slash

    for (const auto& absolutePath : luaurcAbsolutePaths)
    {
        // Get the directory containing the .luaurc file and append .luaurc
        std::string absoluteDir = absolutePath;
        size_t lastSlash = absoluteDir.find_last_of("/\\");
        if (lastSlash != std::string::npos)
        {
            absoluteDir = absoluteDir.substr(0, lastSlash);
        }

        // Convert to relative path and append .luaurc
        std::string relativeLuaurc = ".luaurc";
        if (commonRootLen > 0 && absoluteDir.length() > commonRootLen)
        {
            std::string relativeDir = absoluteDir.substr(commonRootLen);
            relativeLuaurc = relativeDir + "/.luaurc";
        }

        // Read the .luaurc file content
        std::optional<std::string> content = readFile(absolutePath);
        if (content)
        {
            // Store using the .luaurc file path (e.g., "dir/.luaurc" or just ".luaurc")
            luaurcFiles[relativeLuaurc] = *content;
        }
        else
        {
            reporter.formatError("Warning: Could not read .luaurc file '%s'\n", absolutePath.c_str());
        }
    }
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

std::vector<std::pair<std::string, std::string>> StaticRequireTracer::getStaticRequirePairs() const
{
    std::vector<std::pair<std::string, std::string>> pairs;
    pairs.reserve(discovered.size());

    size_t commonRootLen = lowestCommonRoot.empty() ? 0 : lowestCommonRoot.length() + 1; // +1 for the trailing slash

    for (const auto& absolutePath : discovered)
    {
        std::string bundlePath;
        if (commonRootLen > 0 && absolutePath.length() > commonRootLen)
            bundlePath = absolutePath.substr(commonRootLen);
        else
            bundlePath = absolutePath;

        pairs.emplace_back(bundlePath, absolutePath);
    }

    return pairs;
}

bool StaticRequireTracer::containsAbsolute(const std::string& absolutePath) const
{
    return visited.contains(absolutePath);
}

void StaticRequireTracer::printRequireGraph() const
{
    reporter.reportOutput("\nRequire dependency graph:");

    size_t commonRootLen = lowestCommonRoot.empty() ? 0 : lowestCommonRoot.length() + 1;

    for (const auto& [file, deps] : requireGraph)
    {
        // Convert absolute path to bundle path for display
        std::string displayFile;
        if (commonRootLen > 0 && file.length() > commonRootLen)
            displayFile = file.substr(commonRootLen);
        else
            displayFile = file;

        reporter.formatOutput("\t%s", displayFile.c_str());
        for (const auto& dep : deps)
        {
            // Convert absolute path to bundle path for display
            std::string displayDep;
            if (commonRootLen > 0 && dep.length() > commonRootLen)
                displayDep = dep.substr(commonRootLen);
            else
                displayDep = dep;

            reporter.formatOutput("\t\t -> %s", displayDep.c_str());
        }
        if (deps.empty())
        {
            reporter.reportOutput("\t\t(no dependencies)");
        }
    }

    // Print luaurc files found
    if (!luaurcFiles.empty())
    {
        reporter.reportOutput("\n.luaurc files found:");
        for (const auto& [configDir, content] : luaurcFiles)
        {
            reporter.formatOutput("\t%s", configDir.c_str());
        }
    }
    else
    {
        reporter.reportOutput("\nNo .luaurc files found");
    }

    reporter.reportOutput("");
}

std::string StaticRequireTracer::findLowestCommonRoot(const std::vector<std::string>& paths)
{
    if (paths.empty())
        return "";

    if (paths.size() == 1)
    {
        // For a single file, return its directory
        size_t lastSlash = paths[0].find_last_of("/\\");
        if (lastSlash != std::string::npos)
            return paths[0].substr(0, lastSlash);
        return "";
    }

    // Sort the paths - the first and last will have the maximum difference
    std::vector<std::string> sortedPaths = paths;
    std::sort(sortedPaths.begin(), sortedPaths.end());

    const std::string& first = sortedPaths.front();
    const std::string& last = sortedPaths.back();

    // Find common prefix between first and last
    size_t i = 0;
    while (i < first.length() && i < last.length() && first[i] == last[i])
    {
        i++;
    }

    // Back up to the last directory separator
    std::string commonPrefix = first.substr(0, i);
    size_t lastSlash = commonPrefix.find_last_of("/\\");
    if (lastSlash != std::string::npos)
    {
        // Special case: if the slash is at position 0, we're at the root directory
        if (lastSlash == 0)
            return "/";
        return commonPrefix.substr(0, lastSlash);
    }

    return "";
}
