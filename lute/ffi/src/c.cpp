#include "lute/ffi.h"

#include "lua.h"
#include "lualib.h"

#include <array>

const char* const FFIC::properties[] = {nullptr};

const luaL_Reg FFIC::lib[] = {
    {nullptr, nullptr},
};

int FFIC::pushLibrary(lua_State* L)
{
    lua_createtable(L, 0, std::size(FFIC::lib) + std::size(FFIC::properties) - 2);

    for (auto& [name, func] : FFIC::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    return 1;
}

int luteopen_ffi_c(lua_State* L)
{
    return FFIC::pushLibrary(L);
}
