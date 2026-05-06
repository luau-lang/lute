#include "lute/packagerun.h"

#include "lute/common.h"
#include "lute/userlandvfs.h"
#include "lute/uvutils.h"

#include "Luau/FileUtils.h"
#include "Luau/LuauConfig.h"

#include "uv.h"

#include <algorithm>
#include <cctype>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>

static constexpr std::string_view kStorePathPrefix = "@pkg/";

// Expands "@pkg/<key>" to "<homedir>/.loom/store/<key>".
// Returns nullopt if the home directory cannot be determined.
static std::optional<std::string> expandStorePath(std::string_view path)
{
    if (path.substr(0, kStorePathPrefix.size()) != kStorePathPrefix)
        return std::string(path);

    auto result = uvutils::getStringFromUv(uv_os_homedir);
    std::string* homeDir = result.get_if<std::string>();
    if (!homeDir)
        return std::nullopt;

    return *homeDir + "/.loom/store/" + std::string(path.substr(kStorePathPrefix.size()));
}

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
    LUTE_ASSERT(isFile(lockfilePath));

    std::optional<std::string> contents = readFile(lockfilePath);
    if (!contents)
        return {};

    std::optional<Luau::ConfigTable> configOpt = Luau::extractConfig(*contents, {});
    if (!configOpt)
        return {};

    Luau::ConfigTable config = std::move(*configOpt);

    if (!config.contains("packages") || !config.contains("dependencies"))
        return {};

    Luau::ConfigTable* packagesTable = config["packages"].get_if<Luau::ConfigTable>();
    Luau::ConfigTable* depsTable = config["dependencies"].get_if<Luau::ConfigTable>();
    if (!packagesTable || !depsTable)
        return {};

    std::optional<std::string> lockfileParentDir = getParentPath(lockfilePath);
    if (!lockfileParentDir)
        return {};

    // First pass: parse all package entries
    std::unordered_map<std::string, Package::Identifier> keyToIdentifier;
    std::unordered_map<std::string, Package::Info> keyToInfo;
    std::unordered_map<std::string, std::unordered_map<std::string, std::string>> keyToDepAliases;

    for (const auto& [k, v] : *packagesTable)
    {
        const std::string* packageKey = k.get_if<std::string>();
        if (!packageKey)
            return {};

        const Luau::ConfigTable* entry = v.get_if<Luau::ConfigTable>();
        if (!entry || !entry->contains("name"))
            return {};

        const std::string* name = (*entry).find("name")->get_if<std::string>();
        if (!name)
            return {};

        const std::string* rev = entry->contains("rev") ? (*entry).find("rev")->get_if<std::string>() : nullptr;

        Package::Identifier id;
        id.name = toLower(*name);
        id.version = rev ? *rev : "";
        keyToIdentifier[*packageKey] = id;

        Package::Info info;
        if (entry->contains("installPath"))
        {
            const std::string* installPath = (*entry).find("installPath")->get_if<std::string>();
            if (installPath)
            {
                std::optional<std::string> expanded = expandStorePath(*installPath);
                if (!expanded)
                    return {};
                if (isAbsolutePath(*expanded))
                    info.rootDirectory = normalizePath(*expanded);
                else
                    info.rootDirectory = joinPaths(*lockfileParentDir, *expanded);
            }
            else
                info.rootDirectory = joinPaths(*lockfileParentDir, "Packages/" + *packageKey);
        }
        else
        {
            info.rootDirectory = joinPaths(*lockfileParentDir, "Packages/" + *packageKey);
        }

        info.entryFile = getEntryPoint(info.rootDirectory);
        keyToInfo[*packageKey] = std::move(info);

        if (entry->contains("dependencies"))
        {
            const Luau::ConfigTable* entryDeps = (*entry).find("dependencies")->get_if<Luau::ConfigTable>();
            if (entryDeps)
            {
                std::unordered_map<std::string, std::string> aliases;
                for (const auto& [dk, dv] : *entryDeps)
                {
                    const std::string* alias = dk.get_if<std::string>();
                    const std::string* depKey = dv.get_if<std::string>();
                    if (alias && depKey)
                        aliases[*alias] = *depKey;
                }
                keyToDepAliases[*packageKey] = std::move(aliases);
            }
        }
    }

    // Second pass: resolve dependency aliases to Identifiers.
    // The alias name becomes the identifier name so that require("@alias")
    // matches correctly in UserlandVfs::toAliasFallback.
    for (auto& [key, info] : keyToInfo)
    {
        auto aliasIt = keyToDepAliases.find(key);
        if (aliasIt != keyToDepAliases.end())
        {
            for (const auto& [alias, depKey] : aliasIt->second)
            {
                auto idIt = keyToIdentifier.find(depKey);
                if (idIt != keyToIdentifier.end())
                {
                    Package::Identifier aliasedId;
                    aliasedId.name = toLower(alias);
                    aliasedId.version = idIt->second.version;
                    info.dependencies.push_back(std::move(aliasedId));
                }
            }
        }
    }

    // Build direct dependencies from dependencies table (alias -> key map)
    std::vector<Package::Identifier> directDependencies;
    for (const auto& [ak, av] : *depsTable)
    {
        const std::string* depKey = av.get_if<std::string>();
        if (!depKey)
            continue;
        auto it = keyToIdentifier.find(*depKey);
        if (it != keyToIdentifier.end())
            directDependencies.push_back(it->second);
    }

    // Build all dependencies. Each package is registered under its canonical
    // name. Additionally, register alias entries so that require("@alias")
    // can find the package by the alias name used in the lockfile.
    std::vector<std::pair<Package::Identifier, Package::Info>> allDependencies;
    for (auto& [key, id] : keyToIdentifier)
    {
        auto infoIt = keyToInfo.find(key);
        if (infoIt != keyToInfo.end())
            allDependencies.emplace_back(id, infoIt->second);
    }

    // Register alias entries: for each alias in every package's dependency
    // map, add an allDependencies entry keyed by the alias name. This allows
    // UserlandVfs::jumpToDependencySubtree to find the package by alias.
    for (const auto& [key, aliases] : keyToDepAliases)
    {
        for (const auto& [alias, depKey] : aliases)
        {
            std::string lowerAlias = toLower(alias);
            auto idIt = keyToIdentifier.find(depKey);
            auto infoIt = keyToInfo.find(depKey);
            if (idIt != keyToIdentifier.end() && infoIt != keyToInfo.end() && lowerAlias != idIt->second.name)
            {
                Package::Identifier aliasId;
                aliasId.name = lowerAlias;
                aliasId.version = idIt->second.version;
                allDependencies.emplace_back(std::move(aliasId), infoIt->second);
            }
        }
    }

    return {std::move(directDependencies), std::move(allDependencies)};
}
