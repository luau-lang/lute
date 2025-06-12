#pragma once

#include "lute/clivfs.h"

#include "Luau/Require.h"

#include <memory>
#include <string>

void requireConfigInit(luarequire_Configuration* config);

class IRequireVfs
{
public:
    virtual ~IRequireVfs() = default;

    virtual bool isRequireAllowed(lua_State* L, std::string_view requirerChunkname) const = 0;

    virtual NavigationStatus reset(lua_State* L, std::string_view requirerChunkname) = 0;
    virtual NavigationStatus jumpToAlias(lua_State* L, std::string_view path) = 0;

    virtual NavigationStatus toParent(lua_State* L) = 0;
    virtual NavigationStatus toChild(lua_State* L, std::string_view name) = 0;

    virtual bool isModulePresent(lua_State* L) const = 0;
    virtual std::string getContents(lua_State* L, const std::string& loadname) const = 0;

    virtual std::string getChunkname(lua_State* L) const = 0;
    virtual std::string getLoadname(lua_State* L) const = 0;
    virtual std::string getCacheKey(lua_State* L) const = 0;

    virtual bool isConfigPresent(lua_State* L) const = 0;
    virtual std::string getConfig(lua_State* L) const = 0;
};

struct RequireCtx
{
    RequireCtx();
    RequireCtx(CliVfs cliVfs);

    std::unique_ptr<IRequireVfs> vfs;
};
