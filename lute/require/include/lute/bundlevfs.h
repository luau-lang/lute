#pragma once

#include "lute/modulepath.h"

#include "Luau/DenseHash.h"

#include <functional>
#include <optional>
#include <string>

class BundleVfs
{
public:
    BundleVfs(Luau::DenseHashMap<std::string, std::string> luaurcFiles, Luau::DenseHashMap<std::string, std::string> bundleMap);

    NavigationStatus resetToPath(const std::string& path);

    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

    bool isModulePresent() const;
    std::string getIdentifier() const;
    std::optional<std::string> getContents(const std::string& path) const;

    ConfigStatus getConfigStatus() const;
    std::optional<std::string> getConfig() const;

private:
    const Luau::DenseHashMap<std::string, std::string> filePathToBytecode;
    const Luau::DenseHashMap<std::string, std::string> luaurcFiles;
    std::optional<ModulePath> modulePath;
};
