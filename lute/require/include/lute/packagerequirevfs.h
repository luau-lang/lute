#pragma once

#include "lute/require.h"
#include "lute/stdlibvfs.h"
#include "lute/userlandvfs.h"

namespace Package
{

class RequireVfs : public IRequireVfs
{
public:
    RequireVfs(UserlandVfs);

    bool isRequireAllowed(lua_State* L, std::string_view requirerChunkname) const override;

    NavigationStatus reset(lua_State* L, std::string_view requirerChunkname) override;
    NavigationStatus jumpToAlias(lua_State* L, std::string_view path) override;
    NavigationStatus toAliasFallback(lua_State* L, std::string_view aliasUnprefixed) override;

    NavigationStatus toParent(lua_State* L) override;
    NavigationStatus toChild(lua_State* L, std::string_view name) override;

    bool isModulePresent(lua_State* L) const override;
    std::string getContents(lua_State* L, const std::string& loadname) const override;

    std::string getChunkname(lua_State* L) const override;
    std::string getLoadname(lua_State* L) const override;
    std::string getCacheKey(lua_State* L) const override;

    ConfigStatus getConfigStatus(lua_State* L) const override;
    std::string getConfig(lua_State* L) const override;

    bool isPrecompiled() const override
    {
        return false;
    }

private:
    enum class VFSType
    {
        Userland,
        Std,
        Lute,
    };

    VFSType vfsType = VFSType::Userland;

    Package::UserlandVfs userlandVfs;
    StdLibVfs stdLibVfs;
    std::string lutePath;
};

} // namespace Package
