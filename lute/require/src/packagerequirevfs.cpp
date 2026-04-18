#include "lute/packagerequirevfs.h"

#include "lute/common.h"
#include "lute/modulepath.h"

#include "Luau/FileUtils.h"

#include "lua.h"
#include "lualib.h"

#include <optional>
#include <string>
#include <string_view>

namespace Package
{

RequireVfs::RequireVfs(UserlandVfs userlandVfs)
    : userlandVfs(std::move(userlandVfs))
{
}

RequireVfs::RequireVfs(UserlandVfs userlandVfs, CliVfs cliVfs)
    : userlandVfs(std::move(userlandVfs))
    , cliVfs(std::move(cliVfs))
{
}

bool RequireVfs::isRequireAllowed(lua_State* L, std::string_view requirerChunkname) const
{
    bool isStdin = (requirerChunkname == "=stdin");
    bool isFile = (!requirerChunkname.empty() && requirerChunkname[0] == '@');
    bool isStdLibFile = (requirerChunkname.size() >= 6 && requirerChunkname.substr(0, 6) == "@@std/");
    bool isCliFile = (requirerChunkname.size() >= 6 && requirerChunkname.substr(0, 6) == "@@cli/");
    return isStdin || isFile || isStdLibFile || (isCliFile && cliVfs);
}

NavigationStatus RequireVfs::reset(lua_State* L, std::string_view requirerChunkname)
{
    if ((requirerChunkname.size() >= 6 && requirerChunkname.substr(0, 6) == "@@std/"))
    {
        vfsType = VFSType::Std;
        return stdLibVfs.resetToPath(std::string(requirerChunkname.substr(1)));
    }

    if ((requirerChunkname.size() >= 6 && requirerChunkname.substr(0, 6) == "@@cli/"))
    {
        vfsType = VFSType::Cli;
        LUTE_ASSERT(cliVfs);
        return cliVfs->resetToPath(std::string(requirerChunkname.substr(1)));
    }

    if ((requirerChunkname.size() >= 12 && requirerChunkname.substr(0, 12) == "@@batteries/"))
    {
        vfsType = VFSType::Batteries;
        return batteriesVfs.resetToPath(std::string(requirerChunkname.substr(1)));
    }

    vfsType = VFSType::Userland;

    if (requirerChunkname == "=stdin")
        return userlandVfs.resetToStdIn();

    if (requirerChunkname.empty() || requirerChunkname[0] != '@')
        return NavigationStatus::NotFound;

    if (!isAbsolutePath(requirerChunkname.substr(1)))
    {
        // For now, we only support absolute paths.
        return NavigationStatus::NotFound;
    }

    return userlandVfs.resetToPath(std::string(requirerChunkname.substr(1)));
}

NavigationStatus RequireVfs::jumpToAlias(lua_State* L, std::string_view path)
{
    NavigationStatus status = NavigationStatus::NotFound;
    switch (vfsType)
    {
    case VFSType::Userland:
        status = userlandVfs.jumpToAlias(std::string(path));
        break;
    case VFSType::Std:
        status = stdLibVfs.resetToPath(std::string(path));
        break;
    case VFSType::Lute:
        status = luteVfs.resetToPath(std::string(path));
        break;
    case VFSType::Cli:
        LUTE_ASSERT(cliVfs);
        status = cliVfs->resetToPath(std::string(path));
        break;
    case VFSType::Batteries:
        status = batteriesVfs.resetToPath(std::string(path));
        break;
    }
    return status;
}

NavigationStatus RequireVfs::toAliasOverride(lua_State* L, std::string_view aliasUnprefixed)
{
    if (aliasUnprefixed == "std")
    {
        vfsType = VFSType::Std;
        return stdLibVfs.resetToPath("@std");
    }
    else if (aliasUnprefixed == "lute")
    {
        vfsType = VFSType::Lute;
        return luteVfs.resetToPath("@lute");
    }
    else if (aliasUnprefixed == "batteries" && (vfsType == VFSType::Cli || vfsType == VFSType::Std || vfsType == VFSType::Batteries))
    {
        vfsType = VFSType::Batteries;
        return batteriesVfs.resetToPath("@batteries");
    }

    return NavigationStatus::NotFound;
}

NavigationStatus RequireVfs::toAliasFallback(lua_State* L, std::string_view aliasUnprefixed)
{
    NavigationStatus status = userlandVfs.toAliasFallback(aliasUnprefixed);
    if (status == NavigationStatus::Success)
        vfsType = VFSType::Userland;
    return status;
}

NavigationStatus RequireVfs::toParent(lua_State* L)
{
    NavigationStatus status = NavigationStatus::NotFound;
    switch (vfsType)
    {
    case VFSType::Userland:
        status = userlandVfs.toParent();
        break;
    case VFSType::Std:
        status = stdLibVfs.toParent();
        break;
    case VFSType::Lute:
        status = luteVfs.toParent();
        break;
    case VFSType::Cli:
        LUTE_ASSERT(cliVfs);
        status = cliVfs->toParent();
        break;
    case VFSType::Batteries:
        status = batteriesVfs.toParent();
        break;
    }

    return status;
}

NavigationStatus RequireVfs::toChild(lua_State* L, std::string_view name)
{
    switch (vfsType)
    {
    case VFSType::Userland:
        return userlandVfs.toChild(std::string(name));
    case VFSType::Std:
        return stdLibVfs.toChild(std::string(name));
    case VFSType::Lute:
        return luteVfs.toChild(std::string(name));
    case VFSType::Cli:
        LUTE_ASSERT(cliVfs);
        return cliVfs->toChild(std::string(name));
    case VFSType::Batteries:
        return batteriesVfs.toChild(std::string(name));
    }

    return NavigationStatus::NotFound;
}

bool RequireVfs::isModulePresent(lua_State* L) const
{
    switch (vfsType)
    {
    case VFSType::Userland:
        return userlandVfs.isModulePresent();
    case VFSType::Std:
        return stdLibVfs.isModulePresent();
    case VFSType::Lute:
        return luteVfs.isModulePresent();
    case VFSType::Cli:
        LUTE_ASSERT(cliVfs);
        return cliVfs->isModulePresent();
    case VFSType::Batteries:
        return batteriesVfs.isModulePresent();
    }

    return false;
}

std::string RequireVfs::getContents(lua_State* L, const std::string& loadname) const
{
    std::optional<std::string> contents;
    switch (vfsType)
    {
    case VFSType::Userland:
        contents = userlandVfs.getContents(loadname);
        break;
    case VFSType::Std:
        contents = stdLibVfs.getContents(loadname);
        break;
    case VFSType::Lute:
        contents = luteVfs.getContents(loadname);
        break;
    case VFSType::Cli:
        LUTE_ASSERT(cliVfs);
        contents = cliVfs->getContents(loadname);
        break;
    case VFSType::Batteries:
        contents = batteriesVfs.getContents(loadname);
        break;
    }
    return contents ? *contents : "";
}

std::string RequireVfs::getChunkname(lua_State* L) const
{
    std::string chunkname;
    switch (vfsType)
    {
    case VFSType::Userland:
        chunkname = "@" + userlandVfs.getCurrentPath();
        break;
    case VFSType::Std:
        chunkname = "@" + stdLibVfs.getIdentifier();
        break;
    case VFSType::Lute:
        chunkname = "@" + luteVfs.getIdentifier();
        break;
    case VFSType::Cli:
        LUTE_ASSERT(cliVfs);
        chunkname = "@" + cliVfs->getIdentifier();
        break;
    case VFSType::Batteries:
        chunkname = "@" + batteriesVfs.getIdentifier();
        break;
    }
    return chunkname;
}

std::string RequireVfs::getLoadname(lua_State* L) const
{
    std::string loadname;
    switch (vfsType)
    {
    case VFSType::Userland:
        loadname = userlandVfs.getCurrentPath();
        break;
    case VFSType::Std:
        loadname = stdLibVfs.getIdentifier();
        break;
    case VFSType::Lute:
        loadname = luteVfs.getIdentifier();
        break;
    case VFSType::Cli:
        LUTE_ASSERT(cliVfs);
        loadname = cliVfs->getIdentifier();
        break;
    case VFSType::Batteries:
        loadname = batteriesVfs.getIdentifier();
        break;
    }
    return loadname;
}

std::string RequireVfs::getCacheKey(lua_State* L) const
{
    std::string cacheKey;
    switch (vfsType)
    {
    case VFSType::Userland:
        cacheKey = userlandVfs.getCurrentPath();
        break;
    case VFSType::Std:
        cacheKey = stdLibVfs.getIdentifier();
        break;
    case VFSType::Lute:
        cacheKey = luteVfs.getIdentifier();
        break;
    case VFSType::Cli:
        LUTE_ASSERT(cliVfs);
        cacheKey = cliVfs->getIdentifier();
        break;
    case VFSType::Batteries:
        cacheKey = batteriesVfs.getIdentifier();
        break;
    }
    return cacheKey;
}

ConfigStatus RequireVfs::getConfigStatus(lua_State* L) const
{
    ConfigStatus status = ConfigStatus::Ambiguous;
    switch (vfsType)
    {
    case VFSType::Userland:
        status = userlandVfs.getConfigStatus();
        break;
    case VFSType::Std:
        status = stdLibVfs.getConfigStatus();
        break;
    case VFSType::Lute:
        status = luteVfs.getConfigStatus();
        break;
    case VFSType::Cli:
        LUTE_ASSERT(cliVfs);
        status = cliVfs->getConfigStatus();
        break;
    case VFSType::Batteries:
        status = batteriesVfs.getConfigStatus();
        break;
    }
    return status;
}

std::string RequireVfs::getConfig(lua_State* L) const
{
    std::optional<std::string> configContents;
    switch (vfsType)
    {
    case VFSType::Userland:
        configContents = userlandVfs.getConfig();
        break;
    case VFSType::Std:
        configContents = stdLibVfs.getConfig();
        break;
    case VFSType::Lute:
        configContents = luteVfs.getConfig();
        break;
    case VFSType::Cli:
        LUTE_ASSERT(cliVfs);
        configContents = cliVfs->getConfig();
        break;
    case VFSType::Batteries:
        configContents = batteriesVfs.getConfig();
        break;
    }
    return configContents ? *configContents : "";
}

} // namespace Package
