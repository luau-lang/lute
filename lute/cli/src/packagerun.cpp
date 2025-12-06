#include "lute/packagerun.h"

#include "Luau/FileUtils.h"

#include <optional>
#include <regex>
#include <string>
#include <string_view>

std::optional<std::string> getAbsolutePathToNearestLockfile(std::string entryFile)
{
    if (!isAbsolutePath(entryFile))
    {
        std::optional<std::string> cwd = getCurrentWorkingDirectory();
        if (!cwd)
            return std::nullopt;

        entryFile = joinPaths(*cwd, entryFile);
    }
    entryFile = normalizePath(entryFile);

    std::optional<std::string> currentPath = getParentPath(entryFile);
    while (currentPath)
    {
        std::string lockfilePath = joinPaths(*currentPath, "loom.lock");
        if (isFile(lockfilePath))
            return lockfilePath;

        currentPath = getParentPath(*currentPath);
    }

    return std::nullopt;
}

static std::vector<Package::Identifier> extractIdentifiers(std::string lockfileContents)
{
    std::vector<Package::Identifier> packages;

    auto it = lockfileContents.cbegin();
    std::smatch match;
    std::regex re{R"LUTE(name = "([^"]+)"\nversion = "?([^"\n]+)"?)LUTE"};
    while (std::regex_search(it, lockfileContents.cend(), match, re))
    {
        packages.push_back(Package::Identifier{match[1].str(), match[2].str()});
        it = match.suffix().first;
    }

    return packages;
}

// TODO: lockfile must specify entry file location; for now, we try out a few
// likely candidates.
static std::string getEntryPoint(const std::string& packageRoot)
{
    const std::vector<std::string> candidateEntryPoints = {
        "src/init.luau",
        "src/init.lua",
        "init.luau",
        "init.lua",
    };

    for (const std::string& candidate : candidateEntryPoints)
    {
        std::string candidatePath = joinPaths(packageRoot, candidate);
        if (isFile(candidatePath))
            return candidatePath;
    }

    // Fallback to a default even if it doesn't exist
    return joinPaths(packageRoot, "src/init.luau");
}

std::pair<std::vector<Package::Identifier>, std::vector<std::pair<Package::Identifier, Package::Info>>> getDependenciesFromLockfile(
    const std::string& lockfilePath
)
{
    LUAU_ASSERT(isFile(lockfilePath));

    std::optional<std::string> contents = readFile(lockfilePath);
    if (!contents)
        return {};

    std::optional<std::string> lockfileParentDir = getParentPath(lockfilePath);
    if (!lockfileParentDir)
        return {};

    std::string packagesPath = joinPaths(std::move(*lockfileParentDir), "Packages");

    std::vector<Package::Identifier> directDependencies = extractIdentifiers(*contents);
    std::vector<std::pair<Package::Identifier, Package::Info>> allDependencies;
    for (const Package::Identifier& identifier : directDependencies)
    {
        Package::Info info;
        info.rootDirectory = joinPaths(packagesPath, identifier.name);
        info.entryFile = getEntryPoint(info.rootDirectory);

        // TODO: lockfile must specify transitive dependency structure; we must
        // currently make all dependencies available to each other (naively)
        for (const Package::Identifier& identifierInner : directDependencies)
        {
            if (identifier != identifierInner)
            {
                info.dependencies.push_back(identifierInner);
            }
        }

        allDependencies.emplace_back(identifier, std::move(info));
    }

    printf("DUMPING DEPENDENCIES\n");
    for (const Package::Identifier& identifier : directDependencies)
    {
        printf(" - %s@%s\n", identifier.name.c_str(), identifier.version.c_str());
    }
    printf("\nDUMPING ALL DEPENDENCIES\n");
    for (const auto& [identifier, info] : allDependencies)
    {
        printf(" - %s@%s\n", identifier.name.c_str(), identifier.version.c_str());
        printf("   root: %s\n", info.rootDirectory.c_str());
        printf("   entry: %s\n", info.entryFile.c_str());
        printf("   deps:\n");
        for (const Package::Identifier& dep : info.dependencies)
        {
            printf("     - %s@%s\n", dep.name.c_str(), dep.version.c_str());
        }
    }

    return {std::move(directDependencies), std::move(allDependencies)};
}
