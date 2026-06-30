#include "lute/lutevfs.h"

#include "lute/common.h"
#include "lute/crypto.h"
#include "lute/fs.h"
#include "lute/io.h"
#include "lute/keyring.h"
#include "lute/luau.h"
#include "lute/lutemodules.h"
#include "lute/modulepath.h"
#include "lute/net.h"
#include "lute/process.h"
#include "lute/syntax.h"
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
    map["@lute/io.luau"] = luteopen_io;
    map["@lute/keyring.luau"] = luteopen_keyring;
    map["@lute/luau.luau"] = luteopen_luau;
    map["@lute/net/init.luau"] = luteopen_net;
    map["@lute/net/client.luau"] = luteopen_net_client;
    map["@lute/net/server.luau"] = luteopen_net_server;
    map["@lute/process.luau"] = luteopen_process;
    map["@lute/syntax/cst.luau"] = luteopen_syntax;
    map["@lute/syntax/parser.luau"] = luteopen_syntax_parser;
    map["@lute/system.luau"] = luteopen_system;
    map["@lute/task.luau"] = luteopen_task;
    map["@lute/time.luau"] = luteopen_time;
    map["@lute/vm.luau"] = luteopen_vm;
    return map;
}();

static bool isLuteModule(const std::string& path)
{
    return kLuteModules.contains(path);
}

static bool isLuteDirectory(const std::string& path)
{
    if (path == "@lute")
        return true;

    std::string prefix = path + "/";
    for (const auto& [modulePath, open] : kLuteModules)
    {
        if (modulePath.empty() || !open)
            continue;

        if (modulePath.rfind(prefix, 0) == 0)
            return true;
    }

    return false;
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
    LUTE_ASSERT(modulePath);
    return modulePath->toParent();
}

NavigationStatus LuteVfs::toChild(const std::string& name)
{
    LUTE_ASSERT(modulePath);
    return modulePath->toChild(name);
}

bool LuteVfs::isModulePresent() const
{
    LUTE_ASSERT(modulePath);
    ResolvedRealPath result = modulePath->getRealPath();
    LUTE_ASSERT(result.status == NavigationStatus::Success);
    return result.type == ResolvedRealPath::PathType::File;
}

std::string LuteVfs::getIdentifier() const
{
    LUTE_ASSERT(modulePath);
    ResolvedRealPath result = modulePath->getRealPath();
    LUTE_ASSERT(result.status == NavigationStatus::Success);
    return result.realPath;
}

std::optional<std::string> LuteVfs::getContents(const std::string& path) const
{
    LuteModuleResult result = getLuteModule(path);
    if (result.type == LuteModuleType::Module)
        return std::string(result.contents);
    return std::nullopt;
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
