#include "lute/bundlevfs.h"

#include "Luau/Common.h"
#include "Luau/DenseHash.h"

#include <string>
#include <string_view>

constexpr std::string_view kBundlePrefix = "@bundle";
constexpr std::string_view kBundlePrefixPath = "@bundle/";

BundleVfs::BundleVfs(Luau::DenseHashMap<std::string, std::string> luaurcFiles, Luau::DenseHashMap<std::string, std::string> bundleMap)
    : filePathToBytecode(std::move(bundleMap))
    , luaurcFiles(std::move(luaurcFiles))
{
}

static bool isBundleModule(const Luau::DenseHashMap<std::string, std::string>& bundleMap, const std::string& path)
{
    // The bundle root (@bundle or @bundle/) should never be treated as a file
    if (path == kBundlePrefix || path == kBundlePrefixPath)
        return false;

    // Strip @bundle/ prefix if present
    std::string lookupPath = path;
    if (path.rfind(kBundlePrefix, 0) == 0)
        lookupPath = path.substr(kBundlePrefix.size());

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
    if (path.rfind(kBundlePrefix, 0) == 0)
        lookupPath = path.substr(kBundlePrefix.size());

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
    if (path.rfind(kBundlePrefix, 0) != 0)
        return NavigationStatus::NotFound;

    // Strip "@bundle/" to get the actual path
    std::string filePath = path.substr(kBundlePrefix.size());

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
    LUAU_ASSERT(modulePath);
    return modulePath->toParent();
}

NavigationStatus BundleVfs::toChild(const std::string& name)
{
    LUAU_ASSERT(modulePath);
    return modulePath->toChild(name);
}

bool BundleVfs::isModulePresent() const
{
    return isBundleModule(filePathToBytecode, getIdentifier());
}

std::string BundleVfs::getIdentifier() const
{
    LUAU_ASSERT(modulePath);
    ResolvedRealPath result = modulePath->getRealPath();
    LUAU_ASSERT(result.status == NavigationStatus::Success);
    return result.realPath;
}

std::optional<std::string> BundleVfs::getContents(const std::string& path) const
{
    // Strip @bundle/ prefix if present
    std::string lookupPath = path;
    if (path.rfind(kBundlePrefix, 0) == 0)
        lookupPath = path.substr(kBundlePrefix.size());

    // Try direct lookup
    const std::string* value = filePathToBytecode.find(lookupPath);
    if (value != nullptr)
        return *value;

    return std::nullopt;
}

ConfigStatus BundleVfs::getConfigStatus() const
{
    LUAU_ASSERT(modulePath);

    // Get the potential config path for the current module path
    std::string configPath = modulePath->getPotentialConfigPath(".luaurc");

    // Strip @bundle/ prefix if present
    if (configPath.rfind(kBundlePrefix, 0) == 0)
        configPath = configPath.substr(kBundlePrefix.size());

    // Check if this config file exists in our luaurc map
    if (luaurcFiles.find(configPath) != nullptr)
        return ConfigStatus::PresentJson;

    return ConfigStatus::Absent;
}

std::optional<std::string> BundleVfs::getConfig() const
{
    LUAU_ASSERT(modulePath);

    // Get the potential config path for the current module path
    std::string configPath = modulePath->getPotentialConfigPath(".luaurc");

    // Strip @bundle/ prefix if present
    if (configPath.rfind(kBundlePrefix, 0) == 0)
        configPath = configPath.substr(kBundlePrefix.size());

    // Look up the config content in our luaurc map
    const std::string* configContent = luaurcFiles.find(configPath);
    if (configContent != nullptr)
        return *configContent;

    return std::nullopt;
}
