#include "lute/staticrequires.h"

#include "lute/modulepath.h"
#include "lute/resolvemodule.h"
#include "lute/staticrequires.h"

#include "Luau/Ast.h"
#include "Luau/Config.h"
#include "Luau/FileUtils.h"
#include "Luau/LuauConfig.h"
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

void StaticRequireTracer::enablePackageMode(
    std::string projectRootDirectory,
    std::vector<Package::Identifier> directDependencies,
    std::vector<std::pair<Package::Identifier, Package::Info>> allDependencies
)
{
    this->projectRootDirectory.emplace(std::move(projectRootDirectory));
    projectDirectDependencies = directDependencies;
    allPackageDependencies = allDependencies;
    userlandVfs.emplace(Package::UserlandVfs::create(std::move(directDependencies), std::move(allDependencies)));
}

void StaticRequireTracer::trace(const std::string& entryPoint)
{
    visited.clear();
    discovered.clear();
    requireGraph.clear();
    luauConfigFiles.clear();
    packageAliases.clear();

    if (!isAbsolutePath(entryPoint))
    {
        fprintf(stderr, "Error: %s isn't an absolute path\n", entryPoint.c_str());
        return;
    }

    // Temporary set to collect absolute paths to .luaurc files
    Luau::DenseHashSet<std::string> configAbsolutePaths{""};

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

            // Walk up the directory tree looking for .luaurc files
            while (!dir.empty())
            {
                std::string luaurcPath = dir + "/" + Luau::kConfigName;
                std::string luauConfigPath = dir + "/" + Luau::kLuauConfigName;

                bool luaurcExists = isFile(luaurcPath);
                bool luauConfigExists = isFile(luauConfigPath);

                if (luaurcExists && luauConfigExists)
                {
                    reporter.formatError(
                        "Warning: Both %s and %s exist in '%s', preferring %s\n",
                        Luau::kConfigName,
                        Luau::kLuauConfigName,
                        dir.c_str(),
                        Luau::kLuauConfigName
                    );
                    configAbsolutePaths.insert(luauConfigPath);
                }
                else if (luauConfigExists)
                {
                    configAbsolutePaths.insert(luauConfigPath);
                }
                else if (luaurcExists)
                {
                    configAbsolutePaths.insert(luaurcPath);
                }

                if (luaurcExists || luauConfigExists)
                    break;

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
            std::optional<std::string> resolvedPath =
                userlandVfs ? ::resolvePackageModule(req, "@" + filePath, *userlandVfs, &err) : ::resolveModule(req, "@" + filePath, &err);

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
    for (const auto& luaurcPath : configAbsolutePaths)
    {
        allPaths.push_back(luaurcPath);
    }

    lowestCommonRoot = findLowestCommonRoot(allPaths);

    // Convert absolute .luaurc paths to LCR-relative .luaurc paths and read their content
    size_t commonRootLen = lowestCommonRoot.empty() ? 0 : lowestCommonRoot.length() + 1; // +1 for the trailing slash

    for (const auto& absolutePath : configAbsolutePaths)
    {
        // Get the directory and filename of the config file
        std::string absoluteDir = absolutePath;
        std::string configFileName = absoluteDir;
        size_t lastSlash = absoluteDir.find_last_of("/\\");
        if (lastSlash != std::string::npos)
        {
            configFileName = absoluteDir.substr(lastSlash + 1);
            absoluteDir = absoluteDir.substr(0, lastSlash);
        }

        // Convert to relative path and append the config filename
        std::string relativeConfig = configFileName;
        if (commonRootLen > 0 && absoluteDir.length() > commonRootLen)
        {
            std::string relativeDir = absoluteDir.substr(commonRootLen);
            relativeConfig = relativeDir + "/" + configFileName;
        }

        // Read the .luaurc file content
        std::optional<std::string> content = readFile(absolutePath);
        if (content)
        {
            // Store using the config file path (e.g., "dir/.luaurc", ".luaurc", or ".config.luau")
            luauConfigFiles[relativeConfig] = *content;
        }
        else
        {
            reporter.formatError("Warning: Could not read config file '%s'\n", absolutePath.c_str());
        }
    }

    synthesizePackageAliases();
}

void StaticRequireTracer::synthesizePackageAliases()
{
    if (!projectRootDirectory)
        return;

    // Convert an absolute path to a bundle-relative path (without the
    // "@bundle/" prefix). Returns std::nullopt if the path doesn't lie under
    // the lowest common root, which would mean it isn't represented in the
    // bundle at all.
    const std::string& root = lowestCommonRoot;
    auto toBundleRelative = [&](const std::string& absolute) -> std::optional<std::string>
    {
        if (root.empty())
            return absolute;

        // Absolute path must equal LCR or sit under it as a child.
        if (absolute == root)
            return std::string{""};

        // The +1 accounts for the path separator after `root`.
        if (absolute.size() > root.size() + 1 && absolute.compare(0, root.size(), root) == 0 &&
            (absolute[root.size()] == '/' || absolute[root.size()] == '\\'))
        {
            return absolute.substr(root.size() + 1);
        }
        return std::nullopt;
    };

    auto findInfo = [&](const Package::Identifier& id) -> const Package::Info*
    {
        for (const auto& [otherId, info] : allPackageDependencies)
        {
            if (otherId == id)
                return &info;
        }
        return nullptr;
    };

    auto appendAliases = [&](const std::string& subtreePrefix, const std::vector<Package::Identifier>& deps)
    {
        for (const Package::Identifier& dep : deps)
        {
            const Package::Info* info = findInfo(dep);
            if (!info)
            {
                reporter.formatError("Warning: package alias '%s' is missing from the resolved dependency graph\n", dep.name.c_str());
                continue;
            }

            std::optional<std::string> entryRel = toBundleRelative(info->entryFile);
            if (!entryRel)
            {
                reporter.formatError(
                    "Warning: package '%s' entry file '%s' lies outside the bundle root '%s'; skipping alias\n",
                    dep.name.c_str(),
                    info->entryFile.c_str(),
                    root.c_str()
                );
                continue;
            }

            BundlePackageAlias alias;
            alias.requirerSubtreePrefix = subtreePrefix;
            alias.aliasName = dep.name;
            alias.aliasBundlePath = "@bundle/" + *entryRel;
            packageAliases.push_back(std::move(alias));
        }
    };

    // The project itself: any requirer at the bundle root (empty prefix) sees
    // the project's direct dependencies.
    std::optional<std::string> projectPrefix = toBundleRelative(*projectRootDirectory);
    if (!projectPrefix)
    {
        reporter.formatError(
            "Warning: project root '%s' lies outside the bundle root '%s'; package aliases will not be available at runtime\n",
            projectRootDirectory->c_str(),
            root.c_str()
        );
        return;
    }
    appendAliases(*projectPrefix, projectDirectDependencies);

    // Each transitive package: requirers inside that package's root directory
    // see only that package's own direct dependencies. This mirrors the
    // per-package isolation that Package::UserlandVfs enforces at runtime.
    for (const auto& [id, info] : allPackageDependencies)
    {
        if (info.dependencies.empty())
            continue;

        std::optional<std::string> packagePrefix = toBundleRelative(info.rootDirectory);
        if (!packagePrefix)
        {
            reporter.formatError(
                "Warning: package '%s' root '%s' lies outside the bundle root '%s'; aliases for its dependencies will not be available at runtime\n",
                id.name.c_str(),
                info.rootDirectory.c_str(),
                root.c_str()
            );
            continue;
        }

        appendAliases(*packagePrefix, info.dependencies);
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
    if (!luauConfigFiles.empty())
    {
        reporter.reportOutput("\n.luaurc files found:");
        for (const auto& [configDir, content] : luauConfigFiles)
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
