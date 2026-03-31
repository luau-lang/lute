#pragma once

#include "lute/resolveconfig.h"
#include "lute/resolvemodule.h"

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library
int luaopen_luau(lua_State* L);
// open the library as a table on top of the stack
int luteopen_luau(lua_State* L);

namespace luau
{

static const char kSpanType[] = "span";
static const char kCompileResultType[] = "CompileResult";
static const char kSpanCreateName[] = "span.create";

int luau_parse(lua_State* L);

int luau_parseexpr(lua_State* L);

int compile_luau(lua_State* L);

int load_luau(lua_State* L);

int typeofmodule_luau(lua_State* L);

static const luaL_Reg lib[] = {
    {"parse", luau_parse},
    {"parseexpr", luau_parseexpr},
    {"compile", compile_luau},
    {"load", load_luau},
    {"resolveModule", resolveModule_luau},
    {"resolveConfig", resolveConfig_luau},
    {"typeofmodule", typeofmodule_luau},
    {nullptr, nullptr},
};

static const std::string properties[] = {
    kSpanType,
};

} // namespace luau
