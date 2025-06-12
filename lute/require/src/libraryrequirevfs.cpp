#include "lute/libraryrequirevfs.h"

#include "Luau/FileUtils.h"
#include "lua.h"
#include "lualib.h"

#include <optional>
#include <string>
#include <string_view>

namespace Library
{

RequireVfs::RequireVfs(Vfs libraryVfs)
    : libraryVfs(std::move(libraryVfs))
{
}

bool RequireVfs::isRequireAllowed(lua_State* L, std::string_view requirerChunkname) const
{
    bool isFile = (!requirerChunkname.empty() && requirerChunkname[0] == '@');
    bool isStdLibFile = (requirerChunkname.size() >= 6 && requirerChunkname.substr(0, 6) == "@@std/");
    return isFile || isStdLibFile;
}

NavigationStatus RequireVfs::reset(lua_State* L, std::string_view requirerChunkname)
{
    atFakeRoot = false;

    if ((requirerChunkname.size() >= 6 && requirerChunkname.substr(0, 6) == "@@std/"))
    {
        vfsType = VFSType::Std;
        return stdLibVfs.resetToPath(std::string(requirerChunkname.substr(1)));
    }

    vfsType = VFSType::Library;
    if (requirerChunkname.empty() || requirerChunkname[0] != '@')
        return NavigationStatus::NotFound;

    if (!isAbsolutePath(requirerChunkname.substr(1)))
    {
        // For now, we only support absolute paths in the library VFS.
        return NavigationStatus::NotFound;
    }

    return libraryVfs.resetToPath(std::string(requirerChunkname.substr(1)));
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
    else if (!path.empty() && path[0] == '$')
    {
        // "$library:version" is interpreted as a library identifier.
        return libraryVfs.jumpToLibrary(std::string(path));
    }

    switch (vfsType)
    {
    case VFSType::Library:
        return libraryVfs.resetToPath(std::string(path));
    case VFSType::Std:
        return stdLibVfs.resetToPath(std::string(path));
    default:
        return NavigationStatus::NotFound;
    }
}

NavigationStatus RequireVfs::toParent(lua_State* L)
{
    NavigationStatus status;

    switch (vfsType)
    {
    case VFSType::Library:
        status = libraryVfs.toParent();
        break;
    case VFSType::Std:
        status = stdLibVfs.toParent();
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
    case VFSType::Library:
        return libraryVfs.toChild(std::string(name));
    case VFSType::Std:
        return stdLibVfs.toChild(std::string(name));
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
    case VFSType::Library:
        return libraryVfs.isModulePresent();
    case VFSType::Std:
        return stdLibVfs.isModulePresent();
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
    case VFSType::Library:
        contents = libraryVfs.getContents(loadname);
        break;
    case VFSType::Std:
        contents = stdLibVfs.getContents(loadname);
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
    case VFSType::Library:
        return "@" + libraryVfs.getCurrentPath();
    case VFSType::Std:
        return "@" + stdLibVfs.getIdentifier();
    default:
        return "";
    }
}

std::string RequireVfs::getLoadname(lua_State* L) const
{
    switch (vfsType)
    {
    case VFSType::Library:
        return libraryVfs.getCurrentPath();
    case VFSType::Std:
        return stdLibVfs.getIdentifier();
    default:
        return "";
    }
}

std::string RequireVfs::getCacheKey(lua_State* L) const
{
    switch (vfsType)
    {
    case VFSType::Library:
        return libraryVfs.getCurrentPath();
    case VFSType::Std:
        return stdLibVfs.getIdentifier();
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
    case VFSType::Library:
        return libraryVfs.isConfigPresent();
    case VFSType::Std:
        return stdLibVfs.isConfigPresent();
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
    case VFSType::Library:
        configContents = libraryVfs.getConfig();
        break;
    case VFSType::Std:
        configContents = stdLibVfs.getConfig();
        break;
    default:
        break;
    }

    return configContents ? *configContents : "";
}

} // namespace Library
