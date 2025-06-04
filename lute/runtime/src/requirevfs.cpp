#include "lute/requirevfs.h"

#include "lute/modulepath.h"
#include "lute/stdlibvfs.h"

#include "lualib.h"

#include "Luau/Common.h"

RequireVfs::RequireVfs(CliVfs cliVfs)
    : cliVfs(std::move(cliVfs))
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
    atFakeRoot = false;

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

    vfsType = VFSType::Disk;
    if (requirerChunkname == "=stdin")
        return fileVfs.resetToStdIn();

    if (!requirerChunkname.empty() && requirerChunkname[0] == '@')
        return fileVfs.resetToPath(std::string(requirerChunkname.substr(1)));

    return NavigationStatus::NotFound;
}

NavigationStatus RequireVfs::jumpToAlias(lua_State* L, std::string_view path)
{
    if (path == "$std")
    {
        atFakeRoot = false;
        vfsType = VFSType::Std;
        return stdLibVfs.resetToPath("@std");
    }
    else if (path == "$lute")
    {
        vfsType = VFSType::Lute;
        lutePath = "@lute";
        return NavigationStatus::Success;
    }

    switch (vfsType)
    {
    case VFSType::Disk:
        return fileVfs.resetToPath(std::string(path));
    case VFSType::Std:
        return stdLibVfs.resetToPath(std::string(path));
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        return cliVfs->resetToPath(std::string(path));
    default:
        return NavigationStatus::NotFound;
    }
}

NavigationStatus RequireVfs::toParent(lua_State* L)
{
    NavigationStatus status;

    switch (vfsType)
    {
    case VFSType::Disk:
        status = fileVfs.toParent();
        break;
    case VFSType::Std:
        status = stdLibVfs.toParent();
        break;
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        status = cliVfs->toParent();
        break;
    case VFSType::Lute:
        luaL_error(L, "cannot get the parent of @lute");
        break;
    default:
        return NavigationStatus::NotFound;
    }

    if (status == NavigationStatus::NotFound)
    {
        if (atFakeRoot)
            return NavigationStatus::NotFound;

        atFakeRoot = true;
        return NavigationStatus::Success;
    }

    return status;
}

NavigationStatus RequireVfs::toChild(lua_State* L, std::string_view name)
{
    atFakeRoot = false;

    switch (vfsType)
    {
    case VFSType::Disk:
        return fileVfs.toChild(std::string(name));
    case VFSType::Std:
        return stdLibVfs.toChild(std::string(name));
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        return cliVfs->toChild(std::string(name));
    case VFSType::Lute:
        luaL_error(L, "'%s' is not a lute library", std::string(name).c_str());
        break;
    default:
        break;
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
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        return cliVfs->isModulePresent();
    case VFSType::Lute:
        luaL_error(L, "@lute is not requirable");
        break;
    default:
        break;
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
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        contents = cliVfs->getContents(loadname);
        break;
    default:
        break;
    }

    return contents ? *contents : "";
}

std::string RequireVfs::getChunkname(lua_State* L) const
{
    switch (vfsType)
    {
    case VFSType::Disk:
        return "@" + fileVfs.getFilePath();
    case VFSType::Std:
        return "@" + stdLibVfs.getIdentifier();
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        return "@" + cliVfs->getIdentifier();
    default:
        return "";
    }
}

std::string RequireVfs::getLoadname(lua_State* L) const
{
    switch (vfsType)
    {
    case VFSType::Disk:
        return fileVfs.getAbsoluteFilePath();
    case VFSType::Std:
        return stdLibVfs.getIdentifier();
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        return cliVfs->getIdentifier();
    default:
        return "";
    }
}

std::string RequireVfs::getCacheKey(lua_State* L) const
{
    switch (vfsType)
    {
    case VFSType::Disk:
        return fileVfs.getAbsoluteFilePath();
    case VFSType::Std:
        return stdLibVfs.getIdentifier();
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        return cliVfs->getIdentifier();
    default:
        return "";
    }
}

bool RequireVfs::isConfigPresent(lua_State* L) const
{
    if (atFakeRoot)
        return true;

    switch (vfsType)
    {
    case VFSType::Disk:
        return fileVfs.isConfigPresent();
    case VFSType::Std:
        return stdLibVfs.isConfigPresent();
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        return cliVfs->isConfigPresent();
    default:
        return false;
    }
}

std::string RequireVfs::getConfig(lua_State* L) const
{
    if (atFakeRoot)
    {
        std::string globalConfig = "{\n"
                                   "    \"aliases\": {\n"
                                   "        \"std\": \"$std\",\n"
                                   "        \"lute\": \"$lute\",\n"
                                   "    }\n"
                                   "}\n";
        return globalConfig;
    }

    std::optional<std::string> configContents;

    switch (vfsType)
    {
    case VFSType::Disk:
        configContents = fileVfs.getConfig();
        break;
    case VFSType::Std:
        configContents = stdLibVfs.getConfig();
        break;
    case VFSType::Cli:
        LUAU_ASSERT(cliVfs);
        configContents = cliVfs->getConfig();
        break;
    default:
        break;
    }

    return configContents ? *configContents : "";
}
