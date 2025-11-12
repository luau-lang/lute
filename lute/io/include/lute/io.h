#pragma once

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library
int luaopen_io(lua_State* L);
// open the library as a table on top of the stack
int luteopen_io(lua_State* L);

namespace io
{

int read(lua_State* L);

static const luaL_Reg lib[] = {
    {"read", read},

    {nullptr, nullptr}
};

} // namespace io
