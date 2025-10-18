#pragma once

#include "lute/modulepath.h"

#include <optional>
#include <string>
#include <map>

class BundleVfs
{
public:
    BundleVfs() = default;
    BundleVfs(const std::map<std::string, std::string>* bundleMap);

    NavigationStatus resetToPath(const std::string& path);

    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

    bool isModulePresent() const;
    std::string getIdentifier() const;
    std::optional<std::string> getContents(const std::string& path) const;

    bool isConfigPresent() const;
    std::optional<std::string> getConfig() const;

private:
    const std::map<std::string, std::string>* filePathToBytecode = nullptr;
    std::optional<ModulePath> modulePath;
};
