#include "structs.h"

#include "ffi.h"
#include "lua.h"
#include "lualib.h"
#include "lute/userdatas.h"

namespace ffi::cffi
{

int new_c_struct(lua_State* L)
{
    luaL_checktype(L, 1, LUA_TTABLE);

    std::vector<std::pair<std::string, UserdataReference<CType>>> fields;

    int fieldCount = lua_objlen(L, 1);

    for (int i = 0; i < fieldCount; i++)
    {
        if (lua_rawgeti(L, 1, i + 1) != LUA_TTABLE)
        {
            luaL_error(L, "Expected field definition table at index %d", i + 1);
        }

        if (lua_rawgeti(L, -1, 1) != LUA_TSTRING)
        {
            luaL_error(L, "Expected string for field name at index %d", i + 1);
        }
        std::string fieldName = luaL_checkstring(L, -1);
        lua_pop(L, 1);

        if (lua_rawgeti(L, -1, 2) != LUA_TUSERDATA)
        {
            luaL_error(L, "Expected userdata for field type at index %d", i + 1);
        }
        auto fieldType = UserdataReference<CType>{L, -1};
        lua_pop(L, 2);

        fields.emplace_back(std::move(fieldName), std::move(fieldType));
    }


    new (lua_newuserdatataggedwithmetatable(L, sizeof(StructCType), kCTypeTag)) StructCType{fields};

    return 1;
}

int StructCType::deserialize(lua_State* L, const ffi_arg* data)
{
    int fieldsCount = fields.size();

    lua_createtable(L, 0, fieldsCount);

    for (int i = 0; i < fieldsCount; i++)
    {
        auto& [name, type] = fields[i];
        type->deserialize(L, data + elementOffsets[i] / sizeof(ffi_arg));
        lua_setfield(L, -2, name.c_str());
    }

    return 1;
}

void StructCType::serialize(lua_State* L, int index, ffi_arg* to, CallState& state)
{
    luaL_checktype(L, index, LUA_TTABLE);

    int fieldsCount = fields.size();

    for (int i = 0; i < fieldsCount; i++)
    {
        auto& [name, type] = fields[i];
        lua_getfield(L, index, name.c_str());
        type->serialize(L, -1, to + elementOffsets[i], state);
        lua_pop(L, 1);
    }
}
} // namespace ffi::cffi