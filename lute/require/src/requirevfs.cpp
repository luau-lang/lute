#include "lute/requirevfs.h"

#include "lute/bundlevfs.h"
#include "lute/modulepath.h"
#include "lute/stdlibvfs.h"

#include "Luau/Common.h"

#include "lualib.h"

RequireVfs::RequireVfs(CliVfs cliVfs)
    : cliVfs(std::move(cliVfs))
{
}

RequireVfs::RequireVfs(BundleVfs bundleVfs)
    : bundleVfs(std::move(bundleVfs))
{
}

bool RequireVfs::isRequireAllowed(lua_State* L, std::string_view requirerChunkname) const
{
    bool isStdin = (requirerChunkname == "=stdin");
    bool isFile = (!requirerChunkname.empty() && requirerChunkname[0] == '@');
    bool isStdLibFile = (requirerChunkname.size() >= 6 && requirerChunkname.substr(0, 6) == "@@std/");
    bool isCliFile = (requirerChunkname.size() >= 6 && requirerChunkname.substr(0, 6) == "@@cli/");
    bool isBundleFile = (requirerChunkname.size() >= 9 && requirerChunkname.substr(0, 9) == "@@bundle/");
    return isStdin || isFile || isStdLibFile || (isCliFile && cliVfs) || (isBundleFile && bundleVfs);
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
        LUAU_ASSERT(cliVfs);
        return cliVfs->resetToPath(std::string(requirerChunkname.substr(1)));
    }

    if ((requirerChunkname.size() >= 9 && requirerChunkname.substr(0, 9) == "@@bundle/"))
    {
        vfsType = VFSType::Bundle;
        LUAU_ASSERT(bundleVfs);
        return bundleVfs->resetToPath(std::string(requirerChunkname.substr(1)));
    }

    vfsType = VFSType::Disk;
    if (requirerChunkname == "=stdin")
        return fileVfs.resetToStdIn();

    if (!requirerChunkname.empty() && requirerChunkname[0] == '@')
        return fileVfs.resetToPath(std::string(requirerChunkname.substr(1)));

    return NavigationStatus::NotFound;
}

NavigationStatus RequireVfs::jumpToAlias(lua_State* L, std::string_view path)
{
    NavigationStatus status = NavigationStatus::NotFound;
    switch (vfsType)
    {
    case VFSType::Disk:
        status = fileVfs.resetToPath(std::string(path));
        break;
    case VFSType::Std:
        status = stdLibVfs.resetToPath(std::string(path));
        break;
    case VFSType::Lute:
        status = luteVfs.resetToPath(std::string(path));
        break;
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        status = cliVfs->resetToPath(std::string(path));
        break;
    case VFSType::Bundle:
        LUAU_ASSERT(bundleVfs);
        status = bundleVfs->resetToPath(std::string(path));
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

    return NavigationStatus::NotFound;
}

NavigationStatus RequireVfs::toAliasFallback(lua_State* L, std::string_view aliasUnprefixed)
{
    if (vfsType == VFSType::Cli)
    {
        LUAU_ASSERT(cliVfs);
        return cliVfs->toAliasFallback(aliasUnprefixed);
    }
    return NavigationStatus::NotFound;
}

NavigationStatus RequireVfs::toParent(lua_State* L)
{
    NavigationStatus status = NavigationStatus::NotFound;
    switch (vfsType)
    {
    case VFSType::Disk:
        status = fileVfs.toParent();
        break;
    case VFSType::Std:
        status = stdLibVfs.toParent();
        break;
    case VFSType::Lute:
        status = luteVfs.toParent();
        break;
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        status = cliVfs->toParent();
        break;
    case VFSType::Bundle:
        LUAU_ASSERT(bundleVfs);
        status = bundleVfs->toParent();
        break;
    }
    return status;
}

NavigationStatus RequireVfs::toChild(lua_State* L, std::string_view name)
{
    switch (vfsType)
    {
    case VFSType::Disk:
        return fileVfs.toChild(std::string(name));
    case VFSType::Std:
        return stdLibVfs.toChild(std::string(name));
    case VFSType::Lute:
        return luteVfs.toChild(std::string(name));
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        return cliVfs->toChild(std::string(name));
    case VFSType::Bundle:
        LUAU_ASSERT(bundleVfs);
        return bundleVfs->toChild(std::string(name));
    }
    return NavigationStatus::NotFound;
}

bool RequireVfs::isModulePresent(lua_State* L) const
{
    switch (vfsType)
    {
    case VFSType::Disk:
        return fileVfs.isModulePresent();
    case VFSType::Std:
        return stdLibVfs.isModulePresent();
    case VFSType::Lute:
        return luteVfs.isModulePresent();
        break;
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        return cliVfs->isModulePresent();
    case VFSType::Bundle:
        LUAU_ASSERT(bundleVfs);
        return bundleVfs->isModulePresent();
    }

    return false;
}

std::string RequireVfs::getContents(lua_State* L, const std::string& loadname) const
{
    std::optional<std::string> contents;

    switch (vfsType)
    {
    case VFSType::Disk:
        contents = fileVfs.getContents(loadname);
        break;
    case VFSType::Std:
        contents = stdLibVfs.getContents(loadname);
        break;
    case VFSType::Lute:
        contents = luteVfs.getContents(loadname);
        break;
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        contents = cliVfs->getContents(loadname);
        break;
    case VFSType::Bundle:
        LUAU_ASSERT(bundleVfs);
        contents = bundleVfs->getContents(loadname);
        break;
    }

    return contents ? *contents : "";
}

std::string RequireVfs::getChunkname(lua_State* L) const
{
    std::string chunkname;
    switch (vfsType)
    {
    case VFSType::Disk:
        chunkname = "@" + fileVfs.getFilePath();
        break;
    case VFSType::Std:
        chunkname = "@" + stdLibVfs.getIdentifier();
        break;
    case VFSType::Lute:
        chunkname = "@" + luteVfs.getIdentifier();
        break;
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        chunkname = "@" + cliVfs->getIdentifier();
        break;
    case VFSType::Bundle:
        LUAU_ASSERT(bundleVfs);
        chunkname = "@" + bundleVfs->getIdentifier();
        break;
    }
    return chunkname;
}

std::string RequireVfs::getLoadname(lua_State* L) const
{
    std::string loadname;
    switch (vfsType)
    {
    case VFSType::Disk:
        loadname = fileVfs.getAbsoluteFilePath();
        break;
    case VFSType::Std:
        loadname = stdLibVfs.getIdentifier();
        break;
    case VFSType::Lute:
        loadname = luteVfs.getIdentifier();
        break;
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        loadname = cliVfs->getIdentifier();
        break;
    case VFSType::Bundle:
        LUAU_ASSERT(bundleVfs);
        loadname = bundleVfs->getIdentifier();
        break;
    }
    return loadname;
}

std::string RequireVfs::getCacheKey(lua_State* L) const
{
    std::string cacheKey;
    switch (vfsType)
    {
    case VFSType::Disk:
        cacheKey = fileVfs.getAbsoluteFilePath();
        break;
    case VFSType::Std:
        cacheKey = stdLibVfs.getIdentifier();
        break;
    case VFSType::Lute:
        cacheKey = luteVfs.getIdentifier();
        break;
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        cacheKey = cliVfs->getIdentifier();
        break;
    case VFSType::Bundle:
        LUAU_ASSERT(bundleVfs);
        cacheKey = bundleVfs->getIdentifier();
        break;
    }
    return cacheKey;
}

ConfigStatus RequireVfs::getConfigStatus(lua_State* L) const
{
    ConfigStatus status = ConfigStatus::Absent;
    switch (vfsType)
    {
    case VFSType::Disk:
        status = fileVfs.getConfigStatus();
        break;
    case VFSType::Std:
        status = stdLibVfs.getConfigStatus();
        break;
    case VFSType::Lute:
        status = luteVfs.getConfigStatus();
        break;
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        status = cliVfs->getConfigStatus();
        break;
    case VFSType::Bundle:
        LUAU_ASSERT(bundleVfs);
        status = bundleVfs->getConfigStatus();
        break;
    }
    return status;
}

std::string RequireVfs::getConfig(lua_State* L) const
{
    std::optional<std::string> configContents;
    switch (vfsType)
    {
    case VFSType::Disk:
        configContents = fileVfs.getConfig();
        break;
    case VFSType::Std:
        configContents = stdLibVfs.getConfig();
        break;
    case VFSType::Lute:
        configContents = luteVfs.getConfig();
        break;
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        configContents = cliVfs->getConfig();
        break;
    case VFSType::Bundle:
        LUAU_ASSERT(bundleVfs);
        configContents = bundleVfs->getConfig();
        break;
    }
    return configContents ? *configContents : "";
}
