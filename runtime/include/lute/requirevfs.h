#pragma once

#include "lute/filevfs.h"
#include "lute/modulepath.h"
#include "lute/stdlibvfs.h"

#include "lua.h"

#include <string>

class RequireVfs
{
public:
    bool isRequireAllowed(lua_State* L, std::string_view requirerChunkname) const;

    NavigationStatus reset(lua_State* L, std::string_view requirerChunkname);
    NavigationStatus jumpToAlias(lua_State* L, std::string_view path);

    NavigationStatus toParent(lua_State* L);
    NavigationStatus toChild(lua_State* L, std::string_view name);

    bool isModulePresent(lua_State* L) const;
    std::string getContents(lua_State* L, const std::string& loadname) const;

    std::string getChunkname(lua_State* L) const;
    std::string getLoadname(lua_State* L) const;
    std::string getCacheKey(lua_State* L) const;

    bool isConfigPresent(lua_State* L) const;
    std::string getConfig(lua_State* L) const;

private:
    enum class VFSType
    {
        Disk,
        Std,
        Lute,
    };

    VFSType vfsType = VFSType::Disk;

    FileVfs fileVfs;
    StdLibVfs stdLibVfs;
    std::string lutePath;

    bool atFakeRoot = false;
};
