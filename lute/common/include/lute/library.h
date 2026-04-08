#pragma once

#include "lua.h"
#include "lualib.h"

// CRTP base for all lute runtime libraries.
// Each Derived must provide:
//   static constexpr const char kName[];   -- the Lua global name (e.g. "task")
//   static int pushLibrary(lua_State* L);  -- push the library table onto the stack
//   static const luaL_Reg lib[];           -- function registration table (where applicable)
template<typename Derived>
struct LuteLibrary
{
    static int openAsGlobal(lua_State* L)
    {
        Derived::pushLibrary(L);
        lua_setglobal(L, Derived::kName);
        return 1;
    }
};
