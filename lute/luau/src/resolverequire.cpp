#include "lute/resolverequire.h"

#include "lute/filevfs.h"
#include "lute/modulepath.h"

#include "Luau/Common.h"
#include "Luau/RequireNavigator.h"

#include "lua.h"
#include "lualib.h"

#include <optional>
#include <string>

// FileVfsContext
class FileVfsContext : public Luau::Require::NavigationContext
{
public:
    FileVfsContext(std::string requirerChunkname);

    std::string getRequirerIdentifier() const override;

    NavigateResult reset(const std::string& identifier) override;
    NavigateResult jumpToAlias(const std::string& path) override;

    NavigateResult toParent() override;
    NavigateResult toChild(const std::string& component) override;

    ConfigStatus getConfigStatus() const override;

    ConfigBehavior getConfigBehavior() const override;
    std::optional<std::string> getAlias(const std::string& alias) const override;
    std::optional<std::string> getConfig() const override;

    FileVfs vfs;
    std::string requirerChunkname;
};

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

FileVfsContext::FileVfsContext(std::string requirerChunkname)
    : requirerChunkname(std::move(requirerChunkname))
{
}

std::string FileVfsContext::getRequirerIdentifier() const
{
    return requirerChunkname;
}

NC::NavigateResult FileVfsContext::reset(const std::string& identifier)
{
    return convert(vfs.resetToPath(identifier));
}

NC::NavigateResult FileVfsContext::jumpToAlias(const std::string& path)
{
    return convert(vfs.resetToPath(path));
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

std::optional<std::string> FileVfsContext::getAlias(const std::string& alias) const
{
    return std::nullopt;
}

std::optional<std::string> FileVfsContext::getConfig() const
{
    return vfs.getConfig();
}

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
std::optional<std::string> resolveRequire(std::string requirePath, std::string requirerChunkname, std::string* error)
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

int resolverequire_luau(lua_State* L)
{
    std::string requirePath = luaL_checkstring(L, 1);
    std::string requirerChunkname = luaL_checkstring(L, 2);

    std::string error;
    std::optional<std::string> absolutePath = resolveRequire(requirePath, requirerChunkname, &error);
    if (!absolutePath)
        luaL_error(L, "%s", error.c_str());

    lua_pushlstring(L, absolutePath->c_str(), absolutePath->size());
    return 1;
}
