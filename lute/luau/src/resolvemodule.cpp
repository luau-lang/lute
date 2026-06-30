#include "lute/resolvemodule.h"

#include "lute/batteriesvfs.h"
#include "lute/filevfs.h"
#include "lute/lutevfs.h"
#include "lute/modulepath.h"
#include "lute/nativemodule.h"
#include "lute/stdlibvfs.h"

#include "Luau/FileUtils.h"
#include "Luau/RequireNavigator.h"

#include "lua.h"
#include "lualib.h"

#include <optional>
#include <string>

using NC = Luau::Require::NavigationContext;

static NC::NavigateResult convert(NavigationStatus status)
{
    NC::NavigateResult result = NC::NavigateResult::NotFound;
    switch (status)
    {
    case NavigationStatus::Success:
        result = NC::NavigateResult::Success;
        break;
    case NavigationStatus::Ambiguous:
        result = NC::NavigateResult::Ambiguous;
        break;
    case NavigationStatus::NotFound:
        result = NC::NavigateResult::NotFound;
        break;
    }
    return result;
}

static NC::ConfigStatus convert(ConfigStatus status)
{
    NC::ConfigStatus result = NC::ConfigStatus::Ambiguous;
    switch (status)
    {
    case ConfigStatus::Absent:
        result = NC::ConfigStatus::Absent;
        break;
    case ConfigStatus::Ambiguous:
        result = NC::ConfigStatus::Ambiguous;
        break;
    case ConfigStatus::PresentJson:
        result = NC::ConfigStatus::PresentJson;
        break;
    case ConfigStatus::PresentLuau:
        result = NC::ConfigStatus::PresentLuau;
        break;
    }
    return result;
}

// FileVfsContext
class FileVfsContext : public Luau::Require::NavigationContext
{
public:
    FileVfsContext(std::string requirerChunkname);

    NavigateResult resetToRequirer() override;
    NavigateResult jumpToAlias(const std::string& path) override;

    NavigateResult toParent() override;
    NavigateResult toChild(const std::string& component) override;

    ConfigStatus getConfigStatus() const override;

    ConfigBehavior getConfigBehavior() const override;
    std::optional<std::string> getConfig() const override;

    FileVfs vfs;
    std::string requirerChunkname;
};

FileVfsContext::FileVfsContext(std::string requirerChunkname)
    : requirerChunkname(std::move(requirerChunkname))
{
}

NC::NavigateResult FileVfsContext::resetToRequirer()
{
    return convert(vfs.resetToPath(requirerChunkname));
}

NC::NavigateResult FileVfsContext::jumpToAlias(const std::string& path)
{
    return convert(vfs.jumpToAlias(path));
}

NC::NavigateResult FileVfsContext::toParent()
{
    return convert(vfs.toParent());
}

NC::NavigateResult FileVfsContext::toChild(const std::string& component)
{
    return convert(vfs.toChild(component));
}

NC::ConfigStatus FileVfsContext::getConfigStatus() const
{
    return convert(vfs.getConfigStatus());
}

NC::ConfigBehavior FileVfsContext::getConfigBehavior() const
{
    return NC::ConfigBehavior::GetConfig;
}

std::optional<std::string> FileVfsContext::getConfig() const
{
    return vfs.getConfig();
}

struct LuteTypeCheckVfs
{
    FileVfs fileVfs;
    StdLibVfs stdLibVfs;
    LuteVfs luteVfs;
    BatteriesVfs batteriesVfs;

    enum class VFSType
    {
        Disk,
        Std,
        Lute,
        Batteries,
    };
    VFSType vfsType = VFSType::Disk;

    NavigationStatus jumpToAlias(const std::string& path)
    {
        if (vfsType == VFSType::Disk)
        {
            return fileVfs.jumpToAlias(path);
        }
        return resetToPath(path);
    }

    NavigationStatus resetToPath(const std::string& path)
    {
        if (path.rfind("@std", 0) == 0)
        {
            vfsType = VFSType::Std;
            return stdLibVfs.resetToPath(path);
        }
        else if (path.rfind("@lute", 0) == 0)
        {
            vfsType = VFSType::Lute;
            return luteVfs.resetToPath(path);
        }
        else if (path.rfind("@batteries", 0) == 0)
        {
            vfsType = VFSType::Batteries;
            return batteriesVfs.resetToPath(path);
        }
        else
        {
            vfsType = VFSType::Disk;
            std::string diskPath = path;
            if (!diskPath.empty() && diskPath[0] == '@')
                diskPath = diskPath.substr(1);
            return fileVfs.resetToPath(diskPath);
        }
    }

    NavigationStatus toParent()
    {
        switch (vfsType)
        {
        case VFSType::Disk:
            return fileVfs.toParent();
        case VFSType::Std:
            return stdLibVfs.toParent();
        case VFSType::Lute:
            return luteVfs.toParent();
        case VFSType::Batteries:
            return batteriesVfs.toParent();
        }
        return NavigationStatus::NotFound;
    }

    NavigationStatus toChild(const std::string& component)
    {
        switch (vfsType)
        {
        case VFSType::Disk:
            return fileVfs.toChild(component);
        case VFSType::Std:
            return stdLibVfs.toChild(component);
        case VFSType::Lute:
            return luteVfs.toChild(component);
        case VFSType::Batteries:
            return batteriesVfs.toChild(component);
        }
        return NavigationStatus::NotFound;
    }

    std::string getIdentifier() const
    {
        switch (vfsType)
        {
        case VFSType::Disk:
            return fileVfs.getAbsoluteFilePath();
        case VFSType::Std:
            return stdLibVfs.getIdentifier();
        case VFSType::Lute:
            return luteVfs.getIdentifier();
        case VFSType::Batteries:
            return batteriesVfs.getIdentifier();
        }
        return "";
    }

    std::optional<std::string> readSource() const
    {
        std::string identifier = getIdentifier();
        if (identifier.empty())
            return std::nullopt;

        switch (vfsType)
        {
        case VFSType::Std:
            return stdLibVfs.getContents(identifier);
        case VFSType::Lute:
            return luteVfs.getContents(identifier);
        case VFSType::Batteries:
            return batteriesVfs.getContents(identifier);
        default:
            if (isNativeModule(identifier))
                return readNativeModuleTypes(identifier);
            return readFile(identifier);
        }
    }
};

class LuteTypeCheckContext : public Luau::Require::NavigationContext
{
public:
    LuteTypeCheckContext(std::string requirerChunkname)
        : requirerChunkname(std::move(requirerChunkname))
    {
    }

    NavigateResult resetToRequirer() override
    {
        return convert(vfs.resetToPath(requirerChunkname));
    }

    NavigateResult jumpToAlias(const std::string& path) override
    {
        return convert(vfs.jumpToAlias(path));
    }

    NavigateResult toParent() override
    {
        return convert(vfs.toParent());
    }

    NavigateResult toChild(const std::string& component) override
    {
        return convert(vfs.toChild(component));
    }

    NavigateResult toAliasOverride(const std::string& aliasUnprefixed) override
    {
        if (aliasUnprefixed == "std")
        {
            vfs.vfsType = LuteTypeCheckVfs::VFSType::Std;
            return convert(vfs.stdLibVfs.resetToPath("@std"));
        }
        else if (aliasUnprefixed == "lute")
        {
            vfs.vfsType = LuteTypeCheckVfs::VFSType::Lute;
            return convert(vfs.luteVfs.resetToPath("@lute"));
        }
        else if (aliasUnprefixed == "batteries" && vfs.vfsType != LuteTypeCheckVfs::VFSType::Disk)
        {
            vfs.vfsType = LuteTypeCheckVfs::VFSType::Batteries;
            return convert(vfs.batteriesVfs.resetToPath("@batteries"));
        }
        return NC::NavigateResult::NotFound;
    }

    ConfigStatus getConfigStatus() const override
    {
        if (vfs.vfsType == LuteTypeCheckVfs::VFSType::Disk)
            return convert(vfs.fileVfs.getConfigStatus());
        return NC::ConfigStatus::Absent;
    }

    ConfigBehavior getConfigBehavior() const override
    {
        return NC::ConfigBehavior::GetConfig;
    }

    std::optional<std::string> getConfig() const override
    {
        if (vfs.vfsType == LuteTypeCheckVfs::VFSType::Disk)
            return vfs.fileVfs.getConfig();
        return std::nullopt;
    }

    LuteTypeCheckVfs vfs;
    std::string requirerChunkname;
};

// ErrorCapturer
class ErrorCapturer : public Luau::Require::ErrorHandler
{
public:
    void reportError(std::string message) override;
    std::optional<std::string> error = std::nullopt;
};

void ErrorCapturer::reportError(std::string message)
{
    error = message;
}

// Public API
std::optional<std::string> resolveModule(std::string requirePath, std::string requirerChunkname, std::string* error)
{
    if (requirerChunkname.empty() || requirerChunkname[0] != '@')
    {
        if (error)
            *error = "requirer chunkname must start with '@'";
        return std::nullopt;
    }

    FileVfsContext context{requirerChunkname.substr(1)};
    ErrorCapturer errorCapturer{};

    Luau::Require::Navigator navigator{context, errorCapturer};
    Luau::Require::Navigator::Status status = navigator.navigate(requirePath);

    if (status == Luau::Require::Navigator::Status::ErrorReported)
    {
        if (error && errorCapturer.error)
            *error = *errorCapturer.error;
        return std::nullopt;
    }

    std::string absolutePath = context.vfs.getAbsoluteFilePath();
    return absolutePath;
}

std::optional<ResolvedModule> resolveForTypeCheck(std::string requirePath, std::string requirerChunkname, std::string* error)
{
    if (requirerChunkname.empty() || requirerChunkname[0] != '@')
    {
        if (error)
            *error = "requirer chunkname must start with '@'";
        return std::nullopt;
    }

    LuteTypeCheckContext context{requirerChunkname};
    ErrorCapturer errorCapturer{};

    Luau::Require::Navigator navigator{context, errorCapturer};
    Luau::Require::Navigator::Status status = navigator.navigate(requirePath);

    if (status == Luau::Require::Navigator::Status::ErrorReported)
    {
        if (error && errorCapturer.error)
            *error = *errorCapturer.error;
        return std::nullopt;
    }

    std::optional<std::string> source = context.vfs.readSource();
    if (!source)
    {
        if (error)
            *error = "failed to read source for '" + context.vfs.getIdentifier() + "'";
        return std::nullopt;
    }

    ResolvedModule result;
    result.path = context.vfs.getIdentifier();
    result.source = std::move(*source);

    return result;
}

int resolveModule_luau(lua_State* L)
{
    std::string requirePath = luaL_checkstring(L, 1);
    std::string requirerChunkname = luaL_checkstring(L, 2);

    std::string error;
    std::optional<std::string> absolutePath = resolveModule(requirePath, requirerChunkname, &error);
    if (!absolutePath)
        luaL_error(L, "%s", error.c_str());

    lua_pushlstring(L, absolutePath->c_str(), absolutePath->size());
    return 1;
}
