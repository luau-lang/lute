#pragma once

#include "lute/reporter.h"

#include "Luau/DenseHash.h"

#include <optional>
#include <string>
#include <vector>

class StaticRequireTracer
{
public:
    StaticRequireTracer(LuteReporter& reporter);

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
    const Luau::DenseHashMap<std::string, std::string>& getLuaurcFiles() const
    {
        return luaurcFiles;
    }

    void printRequireGraph() const;
    // Find the lowest common root directory from a collection of absolute paths
    static std::string findLowestCommonRoot(const std::vector<std::string>& paths);

private:
    Luau::DenseHashSet<std::string> visited{""};
    std::vector<std::string> discovered;                                        // Absolute paths
    Luau::DenseHashMap<std::string, std::vector<std::string>> requireGraph{""}; // Absolute paths
    Luau::DenseHashMap<std::string, std::string> luaurcFiles{""};               // LCR-relative path -> content
    std::string lowestCommonRoot;

    // Extract all require() paths from source code
    std::vector<std::string> extractRequires(const std::string& source);

    // Resolve a require path relative to the requiring file
    std::optional<std::string> resolveModule(const std::string& requirer, const std::string& required);
    LuteReporter& reporter;
};
