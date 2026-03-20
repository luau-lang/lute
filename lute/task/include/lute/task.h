#pragma once

#include "lua.h"
#include "lualib.h"

// open the library as a standard global luau library
int luaopen_task(lua_State* L);
// open the library as a table on top of the stack
int luteopen_task(lua_State* L);

namespace task
{

int lua_defer(lua_State* L);
int lua_deferSelf(lua_State* L);
int lua_wait(lua_State* L);
int lua_spawn(lua_State* L);
int lute_resume(lua_State* L);
int lua_delay(lua_State* L);

static const luaL_Reg lib[] = {
    {"spawn", lua_spawn},
    {"defer", lua_defer},
    {"resume", lute_resume},
    {"deferSelf", lua_deferSelf},
    {"wait", lua_wait},
    {"delay", lua_delay},
    {nullptr, nullptr},
};

} // namespace task
