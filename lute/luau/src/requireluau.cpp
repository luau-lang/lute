#include "lute/requireluau.h"

#include "Luau/Common.h"
#include "Luau/RequireNavigator.h"
#include "lute/filevfs.h"

#include "lua.h"
#include "lualib.h"

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

    bool isConfigPresent() const override;

    ConfigBehavior getConfigBehavior() const override;
    std::optional<std::string> getAlias(const std::string& alias) const override;
    std::optional<std::string> getConfig() const override;

    FileVfs vfs;
    std::string requirerChunkname;
};

using NavigateResult = Luau::Require::NavigationContext::NavigateResult;
using ConfigBehavior = Luau::Require::NavigationContext::ConfigBehavior;

static NavigateResult convert(NavigationStatus status)
{
    switch (status)
    {
    case NavigationStatus::Success:
        return NavigateResult::Success;
    case NavigationStatus::Ambiguous:
        return NavigateResult::Ambiguous;
    case NavigationStatus::NotFound:
        return NavigateResult::NotFound;
    }
}

FileVfsContext::FileVfsContext(std::string requirerChunkname)
    : requirerChunkname(std::move(requirerChunkname))
{
}

std::string FileVfsContext::getRequirerIdentifier() const
{
    return requirerChunkname;
}

NavigateResult FileVfsContext::reset(const std::string& identifier)
{
    return convert(vfs.resetToPath(identifier));
}

NavigateResult FileVfsContext::jumpToAlias(const std::string& path)
{
    return convert(vfs.resetToPath(path));
}

NavigateResult FileVfsContext::toParent()
{
    return convert(vfs.toParent());
}

NavigateResult FileVfsContext::toChild(const std::string& component)
{
    return convert(vfs.toChild(component));
}

bool FileVfsContext::isConfigPresent() const
{
    return vfs.isConfigPresent();
}

ConfigBehavior FileVfsContext::getConfigBehavior() const
{
    return ConfigBehavior::GetConfig;
}

std::optional<std::string> FileVfsContext::getAlias(const std::string& alias) const
{
    return std::nullopt;
}

std::optional<std::string> FileVfsContext::getConfig() const
{
    return vfs.getConfig();
}

// LuauErrorHandler
class LuauErrorHandler : public Luau::Require::ErrorHandler
{
public:
    LuauErrorHandler(lua_State* L);
    void reportError(std::string message) override;

    lua_State* L;
};

LuauErrorHandler::LuauErrorHandler(lua_State* L)
    : L(L)
{
}

void LuauErrorHandler::reportError(std::string message)
{
    luaL_error(L, "%s", message.c_str());
}

// Public API
int staticrequire_luau(lua_State* L)
{
    std::string path = luaL_checkstring(L, 1);
    std::string requirerChunkname = luaL_checkstring(L, 2);

    if (requirerChunkname.empty() || requirerChunkname[0] != '@')
        luaL_error(L, "requirer chunkname must start with '@'");

    FileVfsContext context{requirerChunkname.substr(1)};
    LuauErrorHandler errorHandler{L};

    Luau::Require::Navigator navigator{context, errorHandler};
    Luau::Require::Navigator::Status status = navigator.navigate(path);

    // Errors should have been reported through LuauErrorHandler
    LUAU_ASSERT(status == Luau::Require::Navigator::Status::Success);

    std::string absolutePath = context.vfs.getAbsoluteFilePath();
    lua_pushlstring(L, absolutePath.c_str(), absolutePath.size());
    return 1;
}
