#pragma once

#include "lua.h"
#include "lualib.h"

#include <optional>
#include <string>

// open the library as a standard global luau library
int luaopen_process(lua_State* L);
// open the library as a table on top of the stack
int luteopen_process(lua_State* L);

namespace process
{

int run(lua_State* L);

int homedir(lua_State* L);
int cwd(lua_State* L);

int exitFunc(lua_State* L);

std::optional<std::string> getExecPath(std::string* error);
int execpath(lua_State* L);

static const luaL_Reg lib[] = {
    {"run", run},
    {"homedir", homedir},
    {"cwd", cwd},
    {"exit", exitFunc},
    {"execpath", execpath},

    {nullptr, nullptr}
};

} // namespace process
