#pragma once

#include "lute/bundlevfs.h"
#include "lute/clivfs.h"
#include "lute/filevfs.h"
#include "lute/libraryvfs.h"
#include "lute/modulepath.h"
#include "lute/require.h"
#include "lute/stdlibvfs.h"

#include "lua.h"

#include <optional>
#include <string>

class RequireVfs : public IRequireVfs
{
public:
    RequireVfs() = default;
    RequireVfs(CliVfs cliVfs);
    RequireVfs(BundleVfs bundleVfs);

    bool isRequireAllowed(lua_State* L, std::string_view requirerChunkname) const override;

    NavigationStatus reset(lua_State* L, std::string_view requirerChunkname) override;
    NavigationStatus jumpToAlias(lua_State* L, std::string_view path) override;

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
        return vfsType == VFSType::Bundle;
    };

private:
    enum class VFSType
    {
        Disk,
        Std,
        Cli,
        Bundle,
        Lute,
    };

    VFSType vfsType = VFSType::Disk;

    FileVfs fileVfs;
    StdLibVfs stdLibVfs;
    std::optional<CliVfs> cliVfs = std::nullopt;
    std::optional<BundleVfs> bundleVfs = std::nullopt;
    std::string lutePath;

    bool atFakeRoot = false;
};
