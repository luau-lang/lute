#pragma once

#include "lua.h"
#include "lualib.h"

#include <type_traits>

#ifndef LUTE_API
#define LUTE_API
#endif

// A uniform interface for Lute libraries.
//
// Each `Derived` Lute library must provide:
//   static constexpr const char kName[];      -- the Luau library name (e.g. "task")
//   static int pushLibrary(lua_State* L);     -- push the library table onto the stack
//   static const luaL_Reg lib[];              -- function registration table
//   static const char* const properties[];    -- non-function table keys (empty array if none)
template<typename Derived>
struct LuteLibrary
{
    // Verifies that the type given as `Derived` satisfies the interface contract.
    //
    // This must be implemented as a function (not in the class scope) because `Derived` is
    // incomplete when `LuteLibrary<Derived>` is instantiated (CRTP constraint).
    static void verifyInterface()
    {
        static_assert(
            std::is_array_v<decltype(Derived::kName)> &&
                std::is_same_v<std::remove_extent_t<decltype(Derived::kName)>, const char>,
            "LuteLibrary must declare: static constexpr const char kName[]"
        );
        static_assert(
            std::is_same_v<decltype(&Derived::pushLibrary), int (*)(lua_State*)>,
            "LuteLibrary must declare: static int pushLibrary(lua_State* L)"
        );
        static_assert(
            std::is_array_v<decltype(Derived::lib)> &&
                std::is_same_v<std::remove_extent_t<decltype(Derived::lib)>, const luaL_Reg>,
            "LuteLibrary must declare: static const luaL_Reg lib[]"
        );
        static_assert(
            std::is_array_v<decltype(Derived::properties)> &&
                std::is_same_v<std::remove_extent_t<decltype(Derived::properties)>, const char* const>,
            "LuteLibrary must declare: static const char* const properties[]"
        );
    }

    static int openAsGlobal(lua_State* L)
    {
        verifyInterface();
        Derived::pushLibrary(L);
        lua_setglobal(L, Derived::kName);
        return 1;
    }
};
