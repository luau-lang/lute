#include "lute/ffi.h"
#include "ffi_c.h"

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

int luteopen_ffi(lua_State* L)
{
    lua_createtable(L, 0, std::size(ffi::lib) - 1 + std::size(ffi::properties));
    luaL_register(L, nullptr, ffi::lib);

    ffi::openCInterface(L);
    lua_setfield(L, -2, ffi::kCInterfaceProperty);

    lua_setreadonly(L, -1, 1);

    return 1;
}
