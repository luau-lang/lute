#include "ffi_c.h"

#include "lua.h"
#include "lualib.h"

#include <array>

int add(int a, int b)
{
    return a + b;
}

namespace ffi
{

static const luaL_Reg clib[] = {
    {nullptr, nullptr}
};

int openCInterface(lua_State* L)
{
    lua_createtable(L, 0, std::size(clib) - 1);
    luaL_register(L, nullptr, clib);

    lua_setreadonly(L, -1, 1);

    return 1;
}

} // namespace ffi
