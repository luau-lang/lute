#include "lute/bundlevfs.h"

#include "Luau/Common.h"

#include <string>

static const std::string BUNDLE_PREFIX = "@bundle/";

BundleVfs::BundleVfs(const Luau::DenseHashMap<std::string, std::string>& bundleMap)
    : filePathToBytecode(bundleMap)
{
}

static bool isBundleModule(const Luau::DenseHashMap<std::string, std::string>& bundleMap, const std::string& path)
{
    // Strip @bundle/ prefix if present
    std::string lookupPath = path;
    if (path.find(BUNDLE_PREFIX) == 0)
        lookupPath = path.substr(BUNDLE_PREFIX.size());

    // Check direct file match
    if (bundleMap.find(lookupPath) != nullptr)
        return true;

    return false;
}

static bool isBundleDirectory(const Luau::DenseHashMap<std::string, std::string>& bundleMap, const std::string& path)
{
    // Strip @bundle/ prefix if present
    std::string lookupPath = path;
    if (path.find(BUNDLE_PREFIX) == 0)
        lookupPath = path.substr(BUNDLE_PREFIX.size());

    // A directory exists if any file in the bundle starts with this path followed by a slash
    std::string prefix = lookupPath + "/";
    for (const auto& [filePath, _] : bundleMap)
    {
        if (filePath.find(prefix) == 0)
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
            [this](const std::string& p) { return isBundleModule(filePathToBytecode, p); },
            [this](const std::string& p) { return isBundleDirectory(filePathToBytecode, p); }
        );
        return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
    }

    // Handle "@bundle/path/to/file"
    if (path.find(BUNDLE_PREFIX) != 0)
        return NavigationStatus::NotFound;

    // Strip "@bundle/" to get the actual path
    std::string filePath = path.substr(BUNDLE_PREFIX.size());

    modulePath = ModulePath::create(
        "@bundle",
        filePath,
        [this](const std::string& p) { return isBundleModule(filePathToBytecode, p); },
        [this](const std::string& p) { return isBundleDirectory(filePathToBytecode, p); }
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
    if (path.find(BUNDLE_PREFIX) == 0)
        lookupPath = path.substr(BUNDLE_PREFIX.size());

    // Try direct lookup
    const auto* value = filePathToBytecode.find(lookupPath);
    if (value != nullptr)
        return *value;

    return std::nullopt;
}

bool BundleVfs::isConfigPresent() const
{
    // Currently, we do not support .luaurc files in bundles.
    return false;
}

std::optional<std::string> BundleVfs::getConfig() const
{
    // Currently, we do not support .luaurc files in bundles.
    return std::nullopt;
}
