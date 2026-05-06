#include "lute/bundlevfs.h"

#include "lute/common.h"

#include "Luau/Common.h"
#include "Luau/DenseHash.h"

#include <algorithm>
#include <string>
#include <string_view>

constexpr std::string_view kBundlePrefix = "@bundle";
constexpr std::string_view kBundlePrefixPath = "@bundle/";

namespace
{

std::string getConfigPathFromBundlePath(const std::string& path)
{
    if (path.rfind(kBundlePrefixPath, 0) == 0)
        return path.substr(kBundlePrefixPath.size());
    return path;
}

} // namespace

BundleVfs::BundleVfs(Luau::DenseHashMap<std::string, std::string> luauConfigFiles, Luau::DenseHashMap<std::string, std::string> bundleMap)
    : filePathToBytecode(std::move(bundleMap))
    , luauConfigFiles(std::move(luauConfigFiles))
{
}

void BundleVfs::setPackageAliases(std::vector<BundlePackageAlias> aliases)
{
    packageAliases = std::move(aliases);
    // Sort longest prefix first so the most specific subtree wins. Stable so
    // tied prefixes keep their incoming order (which is typically insertion
    // order of nested packages first).
    std::stable_sort(
        packageAliases.begin(),
        packageAliases.end(),
        [](const BundlePackageAlias& a, const BundlePackageAlias& b)
        {
            return a.requirerSubtreePrefix.size() > b.requirerSubtreePrefix.size();
        }
    );
}

void BundleVfs::setRequirer(std::string requirerBundlePath)
{
    requirerPath = std::move(requirerBundlePath);
}

namespace
{

// Returns true if `path` lies inside the directory `prefix`. The empty prefix
// matches any path. A non-empty prefix only matches when followed by '/' (or
// the rest of the path is exactly the prefix), so "Packages/dep" does not
// match "Packages/depper/...".
bool isSubtreePrefixOf(std::string_view prefix, std::string_view path)
{
    if (prefix.empty())
        return true;
    if (path.size() < prefix.size())
        return false;
    if (path.substr(0, prefix.size()) != prefix)
        return false;
    return path.size() == prefix.size() || path[prefix.size()] == '/';
}

} // namespace

NavigationStatus BundleVfs::toAliasFallback(std::string_view aliasUnprefixed)
{
    if (packageAliases.empty())
        return NavigationStatus::NotFound;

    // Mirror Package::UserlandVfs's strict isolation: only aliases declared in
    // the most-specific subtree containing the requirer are visible. We find
    // that subtree first (longest matching prefix), then only consult aliases
    // belonging to it. This prevents a transitive dep from accidentally
    // resolving its parent project's aliases.
    std::string_view bestPrefix;
    bool foundSubtree = false;
    for (const BundlePackageAlias& entry : packageAliases)
    {
        if (!isSubtreePrefixOf(entry.requirerSubtreePrefix, requirerPath))
            continue;

        bestPrefix = entry.requirerSubtreePrefix;
        foundSubtree = true;
        break; // packageAliases is sorted longest-prefix-first.
    }

    if (!foundSubtree)
        return NavigationStatus::NotFound;

    for (const BundlePackageAlias& entry : packageAliases)
    {
        if (entry.requirerSubtreePrefix != bestPrefix)
            continue;
        if (entry.aliasName != aliasUnprefixed)
            continue;

        return resetToPath(entry.aliasBundlePath);
    }

    return NavigationStatus::NotFound;
}

static bool isBundleModule(const Luau::DenseHashMap<std::string, std::string>& bundleMap, const std::string& path)
{
    // The bundle root (@bundle or @bundle/) should never be treated as a file
    if (path == kBundlePrefix || path == kBundlePrefixPath)
        return false;

    // Strip @bundle/ prefix if present
    std::string lookupPath = path;
    if (path.rfind(kBundlePrefixPath, 0) == 0)
        lookupPath = path.substr(kBundlePrefixPath.size());

    // The bundle root should never be treated as a file, always as a directory
    // This prevents ambiguity when there's an init.lua at the root
    if (lookupPath == "init.lua" || lookupPath == "init.luau")
        return false;

    // Check direct file match
    if (bundleMap.find(lookupPath) != nullptr)
        return true;

    return false;
}

static bool isBundleDirectory(const Luau::DenseHashMap<std::string, std::string>& bundleMap, const std::string& path)
{
    // Handle the root directory - both "@bundle" and "@bundle/" should be treated as the root
    if (path == kBundlePrefix || path == kBundlePrefixPath)
        return !bundleMap.empty();

    // Strip @bundle/ prefix if present
    std::string lookupPath = path;
    if (path.rfind(kBundlePrefixPath, 0) == 0)
        lookupPath = path.substr(kBundlePrefixPath.size());

    // The root directory (@bundle/) exists if the bundle has any files
    if (lookupPath.empty())
        return !bundleMap.empty();

    // A directory exists if any file in the bundle starts with this path followed by a slash
    std::string prefix = lookupPath + "/";
    for (const auto& [filePath, _] : bundleMap)
    {
        if (filePath.rfind(prefix, 0) == 0)
            return true;
    }

    return false;
}

NavigationStatus BundleVfs::resetToPath(const std::string& path)
{
    // Handle "@bundle" root
    if (path == "@bundle")
    {
        modulePath = ModulePath::create(
            "@bundle",
            "",
            [this](const std::string& p)
            {
                return isBundleModule(filePathToBytecode, p);
            },
            [this](const std::string& p)
            {
                return isBundleDirectory(filePathToBytecode, p);
            }
        );
        return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
    }

    // Handle "@bundle/path/to/file"
    if (path.rfind(kBundlePrefixPath, 0) != 0)
        return NavigationStatus::NotFound;

    // Strip "@bundle/" to get the actual path
    std::string filePath = path.substr(kBundlePrefixPath.size());

    modulePath = ModulePath::create(
        "@bundle",
        filePath,
        [this](const std::string& p)
        {
            return isBundleModule(filePathToBytecode, p);
        },
        [this](const std::string& p)
        {
            return isBundleDirectory(filePathToBytecode, p);
        }
    );

    return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
}

NavigationStatus BundleVfs::toParent()
{
    LUTE_ASSERT(modulePath);
    return modulePath->toParent();
}

NavigationStatus BundleVfs::toChild(const std::string& name)
{
    LUTE_ASSERT(modulePath);
    return modulePath->toChild(name);
}

bool BundleVfs::isModulePresent() const
{
    return isBundleModule(filePathToBytecode, getIdentifier());
}

std::string BundleVfs::getIdentifier() const
{
    LUTE_ASSERT(modulePath);
    ResolvedRealPath result = modulePath->getRealPath();
    LUTE_ASSERT(result.status == NavigationStatus::Success);
    return result.realPath;
}

std::optional<std::string> BundleVfs::getContents(const std::string& path) const
{
    // Strip @bundle/ prefix if present
    std::string lookupPath = path;
    if (path.rfind(kBundlePrefixPath, 0) == 0)
        lookupPath = path.substr(kBundlePrefixPath.size());

    // Try direct lookup
    const std::string* value = filePathToBytecode.find(lookupPath);
    if (value != nullptr)
        return *value;

    return std::nullopt;
}

ConfigStatus BundleVfs::getConfigStatus() const
{
    LUTE_ASSERT(modulePath);

    const std::string luaurcPath = getConfigPathFromBundlePath(modulePath->getPotentialConfigPath(".luaurc"));
    const std::string luauConfigPath = getConfigPathFromBundlePath(modulePath->getPotentialConfigPath(".config.luau"));

    const bool luaurcExists = luauConfigFiles.find(luaurcPath) != nullptr;
    const bool luauConfigExists = luauConfigFiles.find(luauConfigPath) != nullptr;

    if (luaurcExists && luauConfigExists)
        return ConfigStatus::Ambiguous;
    else if (luauConfigExists)
        return ConfigStatus::PresentLuau;
    else if (luaurcExists)
        return ConfigStatus::PresentJson;

    return ConfigStatus::Absent;
}

std::optional<std::string> BundleVfs::getConfig() const
{
    LUTE_ASSERT(modulePath);

    const ConfigStatus status = getConfigStatus();

    std::string configName;
    if (status == ConfigStatus::PresentJson)
        configName = ".luaurc";
    else if (status == ConfigStatus::PresentLuau)
        configName = ".config.luau";
    else
        return std::nullopt;

    const std::string configPath = getConfigPathFromBundlePath(modulePath->getPotentialConfigPath(configName));

    const std::string* configContent = luauConfigFiles.find(configPath);
    if (configContent != nullptr)
        return *configContent;

    return std::nullopt;
}
