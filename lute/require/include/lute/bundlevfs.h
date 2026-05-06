#pragma once

#include "lute/modulepath.h"

#include "Luau/DenseHash.h"

#include <functional>
#include <optional>
#include <string>
#include <utility>
#include <vector>

// One entry in the package alias table embedded in a bundle. A bundled binary
// can declare aliases like `dep -> @bundle/Packages/dep/src/init.luau` that
// only apply to requires originating from inside a particular subtree of the
// bundle (e.g., the project root, or a specific package's own files). This
// mirrors the per-package isolation enforced at runtime by Package::UserlandVfs.
struct BundlePackageAlias
{
    // Bundle-relative directory prefix that scopes this alias. The empty
    // string means "the project root" (any requirer at the bundle root). A
    // non-empty value such as "Packages/dep" matches any requirer whose path
    // starts with that prefix on a directory boundary.
    std::string requirerSubtreePrefix;

    // Unprefixed alias name (no leading '@'), e.g. "dep".
    std::string aliasName;

    // Full bundle path the alias should resolve to, e.g.
    // "@bundle/Packages/dep/src/init.luau".
    std::string aliasBundlePath;
};

class BundleVfs
{
public:
    BundleVfs(Luau::DenseHashMap<std::string, std::string> luauConfigFiles, Luau::DenseHashMap<std::string, std::string> bundleMap);

    // Install the bundle's package alias table. Should be called once after
    // construction, before the BundleVfs is used to service requires.
    void setPackageAliases(std::vector<BundlePackageAlias> aliases);

    // Records the original requirer chunkname for use by toAliasFallback. The
    // navigator may walk the modulePath via toParent before asking for an
    // alias fallback, so we capture the requirer separately. The argument is
    // the bundle-relative path (without any "@bundle/" or "@@bundle/" prefix).
    void setRequirer(std::string requirerBundlePath);

    NavigationStatus resetToPath(const std::string& path);

    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

    // Resolves a package alias (e.g., "dep" for `require("@dep")`) using the
    // current requirer's subtree. Returns NotFound if the alias is not visible
    // from the requirer's subtree.
    NavigationStatus toAliasFallback(std::string_view aliasUnprefixed);

    bool isModulePresent() const;
    std::string getIdentifier() const;
    std::optional<std::string> getContents(const std::string& path) const;

    ConfigStatus getConfigStatus() const;
    std::optional<std::string> getConfig() const;

private:
    const Luau::DenseHashMap<std::string, std::string> filePathToBytecode;
    const Luau::DenseHashMap<std::string, std::string> luauConfigFiles;
    std::optional<ModulePath> modulePath;

    // Sorted by descending requirerSubtreePrefix length so the longest
    // (most-specific) subtree always wins on a prefix match.
    std::vector<BundlePackageAlias> packageAliases;

    // Bundle-relative path of the requirer for the navigation in progress.
    std::string requirerPath;
};
