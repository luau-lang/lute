#include "lute/requirevfs.h"

#include "lute/modulepath.h"
#include "lute/stdlibvfs.h"

#include "lualib.h"

#include "Luau/Common.h"

bool RequireVfs::isRequireAllowed(lua_State* L, std::string_view requirerChunkname) const
{
    bool isStdin = (requirerChunkname == "=stdin");
    bool isFile = (!requirerChunkname.empty() && requirerChunkname[0] == '@');
    bool isStdLibFile = (requirerChunkname.size() >= 6 && requirerChunkname.substr(0, 6) == "@@std/");
    return isStdin || isFile || isStdLibFile;
}

NavigationStatus RequireVfs::reset(lua_State* L, std::string_view requirerChunkname)
{
    atFakeRoot = false;

    if ((requirerChunkname.size() >= 6 && requirerChunkname.substr(0, 6) == "@@std/"))
    {
        vfsType = VFSType::Std;
        return stdLibVfs.resetToPath(std::string(requirerChunkname.substr(1)));
    }
    else
    {
        vfsType = VFSType::Disk;
        if (requirerChunkname == "=stdin")
        {
            return fileVfs.resetToStdIn();
        }
        else if (!requirerChunkname.empty() && requirerChunkname[0] == '@')
        {
            return fileVfs.resetToPath(std::string(requirerChunkname.substr(1)));
        }
    }

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

    if (vfsType == VFSType::Disk)
        return fileVfs.resetToPath(std::string(path));
    else if (vfsType == VFSType::Std)
        return stdLibVfs.resetToPath(std::string(path));

    return NavigationStatus::NotFound;
}

NavigationStatus RequireVfs::toParent(lua_State* L)
{
    NavigationStatus status;
    if (vfsType == VFSType::Disk)
        status = fileVfs.toParent();
    else if (vfsType == VFSType::Std)
        status = stdLibVfs.toParent();
    else if (vfsType == VFSType::Lute)
        luaL_error(L, "cannot get the parent of @lute");
    else
        return NavigationStatus::NotFound;

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

    if (vfsType == VFSType::Disk)
        return fileVfs.toChild(std::string(name));
    else if (vfsType == VFSType::Std)
        return stdLibVfs.toChild(std::string(name));
    else if (vfsType == VFSType::Lute)
        luaL_error(L, "'%s' is not a lute library", std::string(name).c_str());

    return NavigationStatus::NotFound;
}

bool RequireVfs::isModulePresent(lua_State* L) const
{
    if (vfsType == VFSType::Disk)
        return fileVfs.isModulePresent();
    else if (vfsType == VFSType::Std)
        return stdLibVfs.isModulePresent();
    else if (vfsType == VFSType::Lute)
        luaL_error(L, "@lute is not requirable");

    return false;
}

std::string RequireVfs::getContents(lua_State* L, const std::string& loadname) const
{
    std::optional<std::string> contents;

    if (vfsType == VFSType::Disk)
        contents = fileVfs.getContents(loadname);
    else if (vfsType == VFSType::Std)
        contents = stdLibVfs.getContents(loadname);

    return contents ? *contents : "";
}

std::string RequireVfs::getChunkname(lua_State* L) const
{
    if (vfsType == VFSType::Disk)
        return "@" + fileVfs.getFilePath();
    else if (vfsType == VFSType::Std)
        return "@" + stdLibVfs.getIdentifier();

    return "";
}

std::string RequireVfs::getLoadname(lua_State* L) const
{
    if (vfsType == VFSType::Disk)
        return fileVfs.getAbsoluteFilePath();
    else if (vfsType == VFSType::Std)
        return stdLibVfs.getIdentifier();

    return "";
}

std::string RequireVfs::getCacheKey(lua_State* L) const
{
    if (vfsType == VFSType::Disk)
        return fileVfs.getAbsoluteFilePath();
    else if (vfsType == VFSType::Std)
        return stdLibVfs.getIdentifier();

    return "";
}

bool RequireVfs::isConfigPresent(lua_State* L) const
{
    if (atFakeRoot)
        return true;

    if (vfsType == VFSType::Disk)
        return fileVfs.isConfigPresent();
    else if (vfsType == VFSType::Std)
        return fileVfs.isConfigPresent();

    return false;
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

    if (vfsType == VFSType::Disk)
        configContents = fileVfs.getConfig();
    else if (vfsType == VFSType::Std)
        configContents = stdLibVfs.getConfig();

    return configContents ? *configContents : "";
}
