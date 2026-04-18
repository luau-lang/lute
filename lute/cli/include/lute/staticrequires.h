#pragma once

#include "lute/bundlevfs.h"
#include "lute/reporter.h"
#include "lute/userlandvfs.h"

#include "Luau/DenseHash.h"

#include <optional>
#include <string>
#include <utility>
#include <vector>

class StaticRequireTracer
{
public:
    StaticRequireTracer(LuteReporter& reporter);

    // Enables package-aware require resolution and bundle alias generation
    // from a lockfile's resolved dependency graph. After this is called,
    // @<package_alias> requires encountered during tracing are resolved
    // through the package graph, and the bundle's alias table will be
    // populated so the produced executable can resolve those same aliases at
    // runtime via BundleVfs.
    //
    // - projectRootDirectory: absolute path of the directory containing the
    //   loom.lock.luau file (i.e., the project's package root).
    // - directDependencies: aliases the project itself can require.
    // - allDependencies: every package in the resolved graph, with its info.
    void enablePackageMode(
        std::string projectRootDirectory,
        std::vector<Package::Identifier> directDependencies,
        std::vector<std::pair<Package::Identifier, Package::Info>> allDependencies
    );

    // Trace dependencies starting from an entry point file
    // entryPoint: absolute path to entry point file
    void trace(const std::string& entryPoint);

    // Get discovered files as pairs of (bundlePath, absolutePath)
    // bundlePath is the absolute path with the lowest common prefix stripped
    std::vector<std::pair<std::string, std::string>> getStaticRequirePairs() const;

    // Check if an absolute path exists in the discovered files
    bool containsAbsolute(const std::string& absolutePath) const;

    const std::string& getLowestCommonRoot() const
    {
        return lowestCommonRoot;
    }

    // Get discovered .luaurc files as a map of (lcrPath -> content)
    // lcrPath is the absolute path with the lowest common prefix stripped
    const Luau::DenseHashMap<std::string, std::string>& getLuauConfigFiles() const
    {
        return luauConfigFiles;
    }

    // Bundle-scoped package aliases derived from the lockfile after trace().
    // Empty if package mode wasn't enabled.
    const std::vector<BundlePackageAlias>& getPackageAliases() const
    {
        return packageAliases;
    }

    void printRequireGraph() const;
    // Find the lowest common root directory from a collection of absolute paths
    static std::string findLowestCommonRoot(const std::vector<std::string>& paths);

private:
    Luau::DenseHashSet<std::string> visited{""};
    std::vector<std::string> discovered;                                        // Absolute paths
    Luau::DenseHashMap<std::string, std::vector<std::string>> requireGraph{""}; // Absolute paths
    Luau::DenseHashMap<std::string, std::string> luauConfigFiles{""};           // LCR-relative path -> content
    std::string lowestCommonRoot;

    std::optional<Package::UserlandVfs> userlandVfs;

    // Package alias data captured by enablePackageMode for later (post-trace)
    // synthesis of `packageAliases` once we know the LCR.
    std::optional<std::string> projectRootDirectory;
    std::vector<Package::Identifier> projectDirectDependencies;
    std::vector<std::pair<Package::Identifier, Package::Info>> allPackageDependencies;
    std::vector<BundlePackageAlias> packageAliases;

    // Synthesizes packageAliases from the captured package data and the
    // current lowestCommonRoot. Called at the end of trace().
    void synthesizePackageAliases();

    // Extract all require() paths from source code
    std::vector<std::string> extractRequires(const std::string& source);

    // Resolve a require path relative to the requiring file
    std::optional<std::string> resolveModule(const std::string& requirer, const std::string& required);
    LuteReporter& reporter;
};
