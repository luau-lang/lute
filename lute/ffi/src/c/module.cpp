#include "lute/ffi.h"

#include "lua.h"
#include "lualib.h"

#include "memory.h"
#include "types.h"
#include "primitives.h"
#include "functions.h"
#include "library.h"
#include "lute/userdatas.h"

#include <vector>
#include <string_view>

namespace ffi::cffi
{
int pointer(lua_State* L)
{
    void* ptr = lua_tobuffer(L, 1, nullptr);
    lua_pushlightuserdata(L, ptr);
    return 1;
}

static int c_function_ctx(lua_State* L)
{
    int argCount = lua_gettop(L);
    std::vector<UserdataReference<CType>> collectedTypes;

    for (int i = 0; i < argCount; ++i)
    {
        collectedTypes.push_back(UserdataReference<CType>{L, 1 + i});
    }

    auto returnType = UserdataReference<CType>{L, lua_upvalueindex(1)};

    new (lua_newuserdatataggedwithmetatable(L, sizeof(CFunctionType), kCTypeTag))
        CFunctionType{FunctionInfo{std::move(collectedTypes), std::move(returnType)}};

    return 1;
}

int new_c_function(lua_State* L)
{
    luaL_checkudata(L, 1, "ctype");

    lua_pushcclosure(L, c_function_ctx, "cfunctionbuilder", 1);

    return 1;
}

const luaL_Reg cffiLib[] = {
    {"fn", new_c_function},
    {"load", ffi::cffi::load_library},
    {"ptr", ffi::cffi::pointer},
    {"struct", ffi::cffi::new_c_struct},
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
