#include <cstring>

#include "lua.h"
#include "lualib.h"

#include "primitives.h"

namespace ffi::cffi
{

const PrimitiveDef LIBFFI_PRIMITIVES[] = {
    {"void", ffi_type_void},
    {"char", ffi_type_schar},
    {"uchar", ffi_type_uchar},
    {"int", ffi_type_sint},
    {"uint", ffi_type_uint},

    {"uint8", ffi_type_uint8},
    {"int8", ffi_type_sint8},
    {"uint16", ffi_type_uint16},
    {"int16", ffi_type_sint16},
    {"uint32", ffi_type_uint32},
    {"int32", ffi_type_sint32},
    {"float", ffi_type_float},
    {"double", ffi_type_double},

    {"pointer", ffi_type_pointer},
};
const size_t LIBFFI_PRIMITIVES_COUNT = sizeof(LIBFFI_PRIMITIVES) / sizeof(LIBFFI_PRIMITIVES[0]);

static void pushInteger(lua_State* L, const ffi_arg* data)
{
    lua_Integer value = 0;
    std::memcpy(&value, data, sizeof(value));
    lua_pushinteger(L, value);
}

int PrimitiveCType::deserialize(lua_State* L, const ffi_arg* data)
{
    switch (type.type)
    {
    case FFI_TYPE_VOID:
        return 0;
    case FFI_TYPE_INT:
    case FFI_TYPE_SINT8:
    case FFI_TYPE_UINT8:
    case FFI_TYPE_SINT16:
    case FFI_TYPE_UINT16:
    case FFI_TYPE_SINT32:
    case FFI_TYPE_UINT32:
        pushInteger(L, data);
        return 1;
    case FFI_TYPE_FLOAT:
    {
        float value = 0.0f;
        std::memcpy(&value, data, sizeof(value));
        lua_pushnumber(L, value);
        return 1;
    }
    case FFI_TYPE_DOUBLE:
    {
        double value = 0.0;
        std::memcpy(&value, data, sizeof(value));
        lua_pushnumber(L, value);
        return 1;
    }
    case FFI_TYPE_POINTER:
    {
        void* ptr = nullptr;
        std::memcpy(&ptr, data, sizeof(ptr));
        lua_pushlightuserdata(L, ptr);
        return 1;
    }
    default:
        luaL_error(L, "Unsupported primitive type for deserialization");
        return 0;
    }
}

void PrimitiveCType::serialize(lua_State* L, int index, ffi_arg* to, CallState& state)
{
    switch (type.type)
    {
    case FFI_TYPE_VOID:
        return;
    case FFI_TYPE_INT:
    case FFI_TYPE_SINT8:
    case FFI_TYPE_SINT16:
    case FFI_TYPE_SINT32:
    {
        lua_Integer value = luaL_checkinteger(L, index);
        std::memcpy(to, &value, type.size); // Use type.size instead
        return;
    }
    case FFI_TYPE_UINT8:
    case FFI_TYPE_UINT16:
    case FFI_TYPE_UINT32:
    {
        unsigned int value = static_cast<unsigned int>(luaL_checkinteger(L, index));
        std::memcpy(to, &value, type.size);
        return;
    }
    case FFI_TYPE_FLOAT:
    {
        float value = static_cast<float>(luaL_checknumber(L, index));
        std::memcpy(to, &value, sizeof(value));
        return;
    }
    case FFI_TYPE_DOUBLE:
    {
        double value = static_cast<double>(luaL_checknumber(L, index));
        std::memcpy(to, &value, sizeof(value));
        return;
    }
    case FFI_TYPE_POINTER:
    {
        void* pointerValue = nullptr;

        if (lua_isbuffer(L, index))
        {
            pointerValue = luaL_checkbuffer(L, index, nullptr);
        }
        else if (lua_islightuserdata(L, index))
        {
            pointerValue = lua_touserdata(L, index);
        }
        else
        {
            luaL_error(L, "Expected lightuserdata or buffer for pointer type");
        }

        std::memcpy(to, &pointerValue, sizeof(pointerValue));

        return;
    }
    default:
        luaL_error(L, "Unsupported primitive type for serialization");
        return;
    }
}

} // namespace ffi::cffi
