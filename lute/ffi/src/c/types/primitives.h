#pragma once

#include "ffi.h"

#include "ctypes.h"

namespace ffi::cffi
{

class PrimitiveCType : public CType
{
public:
    explicit PrimitiveCType(ffi_type libffi_value)
    {
        type = libffi_value;
    }

    int deserialize(lua_State* L, const ffi_arg* data) override;
    void serialize(lua_State* L, int index, ffi_arg* to, CallState& state) override;

    bool isSymbolPointer() const override
    {
        return false;
    }
};

struct PrimitiveDef
{
    const char* name;
    ffi_type value;
};

extern const PrimitiveDef LIBFFI_PRIMITIVES[];
extern const size_t LIBFFI_PRIMITIVES_COUNT;

} // namespace ffi::cffi
