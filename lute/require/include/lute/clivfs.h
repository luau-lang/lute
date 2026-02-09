#pragma once

#include "lute/modulepath.h"

#include <optional>

class CliVfs
{
public:
    NavigationStatus resetToPath(const std::string& path);

    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);
    NavigationStatus toAliasFallback(std::string_view aliasUnprefixed);

    bool isModulePresent() const;
    std::string getIdentifier() const;
    std::optional<std::string> getContents(const std::string& path) const;

    ConfigStatus getConfigStatus() const;
    std::optional<std::string> getConfig() const;

private:
    std::optional<ModulePath> modulePath;
};
