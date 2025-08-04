#include "ffi_c.h"

#include "lua.h"
#include "lualib.h"

#include "ffi.h"

#include <array>

int add(int a, int b)
{
    return a + b;
}

namespace ffi
{

int lua_ctestadd(lua_State* L)
{
    int a = luaL_checkinteger(L, 1);
    int b = luaL_checkinteger(L, 2);

    ffi_cif cif;
    ffi_type* types[2];

    types[0] = &ffi_type_sint;
    types[1] = &ffi_type_sint;

    if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 2, &ffi_type_sint, types) != FFI_OK)
    {
        luaL_error(L, "could not prepare call interface");
    }

    void* values[2];
    int result;

    values[0] = &a;
    values[1] = &b;

    ffi_call(&cif, FFI_FN(add), &result, values);

    lua_pushinteger(L, result);
    return 1;
}

static const luaL_Reg clib[] = {
    {"testadd", lua_ctestadd},

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
