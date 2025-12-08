#include <string_view>
#include <vector>

#include "lua.h"
#include "lualib.h"

#include "lute/ffi.h"
#include "lute/userdatas.h"

#include "ctypes.h"
#include "library.h"
#include "types/functions.h"
#include "types/primitives.h"

namespace ffi::cffi
{

const luaL_Reg cffiLib[] = {
    {"fn", ffi::cffi::newCFunction},
    {"load", ffi::cffi::loadLibrary},
    {"struct", ffi::cffi::newCStruct},
    {"const", ffi::cffi::newCConstant},
    {NULL, NULL}
};

template<typename T>
void dtor_userdata(lua_State* L, void* ptr)
{
    static_cast<T*>(ptr)->~T();
}

static void openTypes(lua_State* L)
{
    {
        luaL_newmetatable(L, "ctype");

        lua_pushcfunction(
            L,
            [](lua_State* L) -> int
            {
                auto* ctype = static_cast<CType*>(luaL_checkudata(L, 1, "ctype"));
                std::string_view key = luaL_checkstring(L, 2);

                if (key == "size")
                {
                    lua_pushinteger(L, ctype->type.size);
                    return 1;
                }

                return 0;
            },
            "ctype.__index"
        );
        lua_setfield(L, -2, "__index");

        lua_pushstring(L, "ctype");
        lua_setfield(L, -2, "__type");

        lua_setuserdatametatable(L, kCTypeTag);
    }

    lua_setuserdatadtor(L, kCTypeTag, dtor_userdata<CType>);
    lua_setuserdatadtor(L, kCFunctionTag, dtor_userdata<CFunction>);
}
} // namespace ffi::cffi

int ffi::luaopen_cffi(lua_State* L)
{
    using namespace ffi::cffi;

    cffi::openTypes(L);

    lua_createtable(L, 0, std::size(cffiLib) + LIBFFI_PRIMITIVES_COUNT);

    luaL_register(L, nullptr, cffiLib);

    for (size_t i = 0; i < LIBFFI_PRIMITIVES_COUNT; ++i)
    {
        const auto& ct = LIBFFI_PRIMITIVES[i];
        new (lua_newuserdatataggedwithmetatable(L, sizeof(PrimitiveCType), kCTypeTag)) PrimitiveCType(ct.value);
        lua_setfield(L, -2, ct.name);
    }

    lua_setreadonly(L, -1, 1);

    return 1;
}
