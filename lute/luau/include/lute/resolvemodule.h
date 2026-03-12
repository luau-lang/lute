#pragma once

#include <optional>
#include <string>

struct lua_State;

struct ResolvedModule
{
    std::string path;
    std::optional<std::string> source;
};

std::optional<std::string> resolveModule(std::string requirePath, std::string requirerChunkname, std::string* error);
std::optional<ResolvedModule> resolveForTypeCheck(std::string requirePath, std::string requirerChunkname, std::string* error);

int resolveModule_luau(lua_State* L);
