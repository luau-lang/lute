#pragma once

#include "lute/modulepath.h"

#include <optional>

class CliVfs
{
public:
    NavigationStatus resetToPath(const std::string& path);

    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

    bool isModulePresent() const;
    std::string getIdentifier() const;
    std::optional<std::string> getContents(const std::string& path) const;

    bool isConfigPresent() const;
    std::optional<std::string> getConfig() const;

private:
    std::optional<ModulePath> modulePath;
};
