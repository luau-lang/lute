#pragma once

#include <string>
#include <vector>
#include <set>
#include <map>
#include <optional>

class StaticRequireTracer
{
public:
    StaticRequireTracer() = default;

    // Trace dependencies starting from an entry point file
    // rootDirectory: Base directory for resolving all requires
    // entryPoint: Path to entry point file (relative to rootDirectory)
    // Returns list of all files in dependency order (entry point first)
    std::vector<std::string> trace(const std::string& rootDirectory, const std::string& entryPoint);

    // Get the require graph built during the last trace
    // Maps each file to the list of files it requires
    const std::map<std::string, std::vector<std::string>>& getRequireGraph() const { return requireGraph; }

private:
    std::set<std::string> visited;
    std::vector<std::string> discovered;
    std::map<std::string, std::vector<std::string>> requireGraph;
    std::string rootDirectory;

    // Extract all require() paths from source code
    std::vector<std::string> extractRequires(const std::string& source);

    // Resolve a require path relative to the requiring file
    std::optional<std::string> resolveRequire(const std::string& requirer, const std::string& required);
};
