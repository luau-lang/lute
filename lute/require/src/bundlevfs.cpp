#include "lute/bundlevfs.h"

#include "Luau/Common.h"

#include <string>

BundleVfs::BundleVfs(const std::map<std::string, std::string>* bundleMap)
    : filePathToBytecode(bundleMap)
{
}

static bool isBundleModule(const std::map<std::string, std::string>* bundleMap, const std::string& path)
{
    if (!bundleMap)
        return false;

    // Strip @bundle/ prefix if present
    std::string lookupPath = path;
    std::string bundlePrefix = "@bundle/";
    if (path.find(bundlePrefix) == 0)
        lookupPath = path.substr(bundlePrefix.size());

    // Check direct file match
    if (bundleMap->find(lookupPath) != bundleMap->end())
        return true;

    // Check with .luau extension
    if (bundleMap->find(lookupPath + ".luau") != bundleMap->end())
        return true;

    // Check with .lua extension
    if (bundleMap->find(lookupPath + ".lua") != bundleMap->end())
        return true;

    // Check for init.luau in directory
    if (bundleMap->find(lookupPath + "/init.luau") != bundleMap->end())
        return true;

    // Check for init.lua in directory
    if (bundleMap->find(lookupPath + "/init.lua") != bundleMap->end())
        return true;

    return false;
}
[[maybe_unused]]
static bool isBundleDirectory(const std::map<std::string, std::string>* bundleMap, const std::string& path)
{
    if (!bundleMap)
        return false;

    // Strip @bundle/ prefix if present
    std::string lookupPath = path;
    std::string bundlePrefix = "@bundle/";
    if (path.find(bundlePrefix) == 0)
        lookupPath = path.substr(bundlePrefix.size());

    // A directory exists if any file in the bundle starts with this path followed by a slash
    std::string prefix = lookupPath + "/";
    for (const auto& [filePath, _] : *bundleMap)
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
    std::string bundlePrefix = "@bundle/";
    if (path.find(bundlePrefix) != 0)
        return NavigationStatus::NotFound;

    // Strip "@bundle/" to get the actual path
    std::string filePath = path.substr(bundlePrefix.size());

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
    if (!filePathToBytecode)
        return std::nullopt;

    // Strip @bundle/ prefix if present
    std::string lookupPath = path;
    std::string bundlePrefix = "@bundle/";
    if (path.find(bundlePrefix) == 0)
        lookupPath = path.substr(bundlePrefix.size());

    // Try direct lookup
    auto it = filePathToBytecode->find(lookupPath);
    if (it != filePathToBytecode->end())
        return it->second;

    // Try with .luau extension
    it = filePathToBytecode->find(lookupPath + ".luau");
    if (it != filePathToBytecode->end())
        return it->second;

    // Try with .lua extension
    it = filePathToBytecode->find(lookupPath + ".lua");
    if (it != filePathToBytecode->end())
        return it->second;

    // Try init.luau
    it = filePathToBytecode->find(lookupPath + "/init.luau");
    if (it != filePathToBytecode->end())
        return it->second;

    // Try init.lua
    it = filePathToBytecode->find(lookupPath + "/init.lua");
    if (it != filePathToBytecode->end())
        return it->second;

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
