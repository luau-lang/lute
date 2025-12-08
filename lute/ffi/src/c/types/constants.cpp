#include "ffi.h"

#include "lute/userdatas.h"

#include "constants.h"
#include "primitives.h"

namespace ffi::cffi
{

int CConstant::deserialize(lua_State* L, const ffi_arg* data)
{
    return innerType->deserialize(L, data);
}

void CConstant::serialize(lua_State* L, int index, ffi_arg* to, CallState& state)
{
    if (auto primitive = dynamic_cast<PrimitiveCType*>(this->innerType.get()))
    {
        if (primitive->type.type == FFI_TYPE_POINTER)
        {
            // string special-case
            if (lua_type(L, index) == LUA_TSTRING)
            {
                const char* str = lua_tostring(L, index);

                std::memcpy(to, &str, sizeof(const char*));
                return;
            }
        }
    }

    innerType->serialize(L, index, to, state);
}

int newCConstant(lua_State* L)
{
    UserdataReference<CType> inner{L, -1};

    new (lua_newuserdatataggedwithmetatable(L, sizeof(CConstant), kCTypeTag)) CConstant{std::move(inner)};

    return 1;
}

} // namespace ffi::cffi