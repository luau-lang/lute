#include "lute/ffi.h"

#include "lua.h"
#include "lualib.h"

#include <array>

const char* const FFI::properties[] = {"c"};

const luaL_Reg FFI::lib[] = {
    {nullptr, nullptr},
};

int FFI::pushLibrary(lua_State* L)
{
    lua_createtable(L, 0, std::size(FFI::properties) + std::size(FFI::lib));

    FFIC::verifyInterface();
    FFIC::pushLibrary(L);
    lua_setfield(L, -2, "c");

    lua_setreadonly(L, -1, 1);

    return 1;
}

int luaopen_ffi(lua_State* L)
{
    return FFI::openAsGlobal(L);
}

int luteopen_ffi(lua_State* L)
{
    return FFI::pushLibrary(L);
}
