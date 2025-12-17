#pragma once

#include "lute/modulepath.h"

#include "Luau/DenseHash.h"

#include "lua.h"

#include <string>

extern const Luau::DenseHashMap<std::string, lua_CFunction> kLuteModules;

class LuteVfs
{
public:
    NavigationStatus resetToPath(const std::string& path);

    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

    bool isModulePresent() const;
    std::string getIdentifier() const;
    std::optional<std::string> getContents(const std::string& path) const;

    ConfigStatus getConfigStatus() const;
    std::optional<std::string> getConfig() const;

private:
    std::optional<ModulePath> modulePath;
};
