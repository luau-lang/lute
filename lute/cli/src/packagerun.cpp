#include "lute/packagerun.h"

#include "lute/userlandvfs.h"

#include "Luau/FileUtils.h"
#include "Luau/LuauConfig.h"

#include <algorithm>
#include <cctype>
#include <optional>
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
        std::string lockfilePath = joinPaths(*currentPath, "loom.lock.luau");
        if (isFile(lockfilePath))
            return lockfilePath;

        currentPath = getParentPath(*currentPath);
    }

    return std::nullopt;
}

static std::string toLower(std::string_view str)
{
    std::string result(str);
    std::transform(
        result.begin(),
        result.end(),
        result.begin(),
        [](unsigned char c)
        {
            return std::tolower(c);
        }
    );
    return result;
}

static std::vector<Package::Identifier> extractIdentifiers(std::string lockfileContents)
{
    // TODO: support timing out Luau-syntax configurations
    std::optional<Luau::ConfigTable> configOpt = Luau::extractConfig(lockfileContents, {});
    if (!configOpt)
        return {};

    Luau::ConfigTable config = std::move(*configOpt);
    if (!config.contains("package"))
        return {};

    Luau::ConfigTable* packageTable = config["package"].get_if<Luau::ConfigTable>();
    if (!packageTable)
        return {};

    std::vector<Package::Identifier> packages;
    packages.resize(packageTable->size());

    for (const auto& [k, v] : *packageTable)
    {
        const double* key = k.get_if<double>();
        if (!key)
            return {};

        const size_t index = static_cast<size_t>(*key);
        if (index < 1 || packageTable->size() < index)
            return {};

        const Luau::ConfigTable* package = v.get_if<Luau::ConfigTable>();
        if (!package)
            return {};

        if (!package->contains("name") || !package->contains("rev"))
            return {};

        const std::string* name = (*package).find("name")->get_if<std::string>();
        const std::string* rev = (*package).find("rev")->get_if<std::string>();

        if (!name || !rev)
            return {};

        Package::Identifier entry{};
        entry.name = toLower(*name);
        entry.version = *rev;
        packages[index - 1] = std::move(entry);
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

        // TODO: lockfile must specify transitive dependency structure; we
        // currently make all dependencies available to each other.
        info.dependencies = directDependencies;

        allDependencies.emplace_back(identifier, std::move(info));
    }

    return {std::move(directDependencies), std::move(allDependencies)};
}
