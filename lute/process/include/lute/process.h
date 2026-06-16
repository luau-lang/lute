#pragma once

#include "lute/library.h"

#include "lua.h"
#include "lualib.h"

#include <optional>
#include <string>

// open the library as a standard global luau library
LUTE_API int luaopen_process(lua_State* L);
// open the library as a table on top of the stack
LUTE_API int luteopen_process(lua_State* L);

struct Process : LuteLibrary<Process>
{
    static constexpr const char kName[] = "process";
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
    static const char* const properties[];

    static std::optional<std::string> getExecPath(std::string* error);
};
