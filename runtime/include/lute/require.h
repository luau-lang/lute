#pragma once

#include "lute/requireutils.h"

#include "Luau/Require.h"

#include <optional>
#include <string>

struct lua_State;

void requireConfigInit(luarequire_Configuration* config);

struct RequireCtx
{
    RequireCtx() = default;
    RequireCtx(std::string sourceOverride)
        : sourceOverride(std::move(sourceOverride))
    {
    }

    std::optional<std::string> sourceOverride = std::nullopt;

    std::string absPath;
    std::string relPath;
    std::string suffix;

    VFSType currentVFSType = VFSType::Disk;

    bool atFakeRoot = false;
};
