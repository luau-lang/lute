#pragma once

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library
int luaopen_io(lua_State* L);
// open the library as a table on top of the stack
int luteopen_io(lua_State* L);

namespace io
{

int input(lua_State* L);

static const luaL_Reg lib[] = {
    {"input", input},

    {nullptr, nullptr}
};

} // namespace io
