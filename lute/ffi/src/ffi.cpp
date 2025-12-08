#include "lute/ffi.h"

#include "lua.h"
#include "lualib.h"

#include <array>

namespace ffi
{

} // namespace ffi

int luaopen_ffi(lua_State* L)
{
    luteopen_ffi(L);
    lua_setglobal(L, "ffi");

    return 1;
}

const struct {
    const char* libname;
    int (*open)(lua_State* L);
} ABI_LIBS[] = {
    {"c", ffi::luaopen_cffi},
    {NULL, NULL}
};

int luteopen_ffi(lua_State* L)
{
    lua_createtable(L, 0, std::size(ABI_LIBS));

    for (int i = 0; ABI_LIBS[i].libname != NULL; ++i)
    {
        ABI_LIBS[i].open(L);

        lua_setfield(L, -2, ABI_LIBS[i].libname);
    }

    lua_setreadonly(L, -1, 1);

    return 1;
}
