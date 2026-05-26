#pragma once

#include "lute/library.h"

#include "lua.h"
#include "lualib.h"

LUTE_API int luaopen_tty(lua_State* L);
LUTE_API int luteopen_tty(lua_State* L);

struct TTY : LuteLibrary<TTY>
{
    static constexpr const char kName[] = "tty";
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
    static const char* const properties[];
};
