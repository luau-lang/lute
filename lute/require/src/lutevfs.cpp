#include "lute/lutevfs.h"

#include "lute/crypto.h"
#include "lute/fs.h"
#include "lute/io.h"
#include "lute/luau.h"
#include "lute/modulepath.h"
#include "lute/net.h"
#include "lute/process.h"
#include "lute/system.h"
#include "lute/task.h"
#include "lute/time.h"
#include "lute/vm.h"

#include "Luau/DenseHash.h"

#include "lua.h"

const Luau::DenseHashMap<std::string, lua_CFunction> kLuteModules = []()
{
    Luau::DenseHashMap<std::string, lua_CFunction> map{""};
    map["@lute/crypto.luau"] = luteopen_crypto;
    map["@lute/fs.luau"] = luteopen_fs;
    map["@lute/luau.luau"] = luteopen_luau;
    map["@lute/net.luau"] = luteopen_net;
    map["@lute/process.luau"] = luteopen_process;
    map["@lute/task.luau"] = luteopen_task;
    map["@lute/vm.luau"] = luteopen_vm;
    map["@lute/system.luau"] = luteopen_system;
    map["@lute/time.luau"] = luteopen_time;
    map["@lute/io.luau"] = luteopen_io;
    return map;
}();

static bool isLuteModule(const std::string& path)
{
    return kLuteModules.contains(path);
}

static bool isLuteDirectory(const std::string& path)
{
    return path == "@lute";
}

NavigationStatus LuteVfs::resetToPath(const std::string& path)
{
    if (path == "@lute")
    {
        modulePath = ModulePath::create("@lute", "", isLuteModule, isLuteDirectory);
        return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
    }

    std::string lutePrefix = "@lute/";

    if (path.rfind(lutePrefix, 0) != 0)
        return NavigationStatus::NotFound;

    modulePath = ModulePath::create("@lute", path.substr(lutePrefix.size()), isLuteModule, isLuteDirectory);
    return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
}

NavigationStatus LuteVfs::toParent()
{
    LUAU_ASSERT(modulePath);
    return modulePath->toParent();
}

NavigationStatus LuteVfs::toChild(const std::string& name)
{
    LUAU_ASSERT(modulePath);
    return modulePath->toChild(name);
}

bool LuteVfs::isModulePresent() const
{
    LUAU_ASSERT(modulePath);
    ResolvedRealPath result = modulePath->getRealPath();
    LUAU_ASSERT(result.status == NavigationStatus::Success);
    return result.type == ResolvedRealPath::PathType::File;
}

std::string LuteVfs::getIdentifier() const
{
    LUAU_ASSERT(modulePath);
    ResolvedRealPath result = modulePath->getRealPath();
    LUAU_ASSERT(result.status == NavigationStatus::Success);
    return result.realPath;
}

std::optional<std::string> LuteVfs::getContents(const std::string& path) const
{
    // Lute modules have no source code.
    return "";
}

ConfigStatus LuteVfs::getConfigStatus() const
{
    // Currently, we do not support .luaurc files in Lute commands.
    return ConfigStatus::Absent;
}

std::optional<std::string> LuteVfs::getConfig() const
{
    // Currently, we do not support .luaurc files in Lute commands.
    return std::nullopt;
}
