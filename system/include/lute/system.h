#pragma once

#include "lua.h"
#include "lualib.h"
#include <string>

// open the library as a standard global luau library
int luaopen_system(lua_State* L);
// open the library as a table on top of the stack
int luteopen_system(lua_State* L);

namespace libsystem
{

static const char kArchitectureProperty[] = "arch";
static const char kOperatingSystemProperty[] = "os";

int lua_cpus(lua_State* L);
int lua_threadcount(lua_State* L);

static const luaL_Reg lib[] = {
    {"cpus", lua_cpus},
    {"threadcount", lua_threadcount},

    {nullptr, nullptr}
};

static const std::string properties[] = {
    kArchitectureProperty,
    kOperatingSystemProperty,
};

} // namespace libsystem
