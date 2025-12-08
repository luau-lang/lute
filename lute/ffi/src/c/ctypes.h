#pragma once

#include "lua.h"
#include "ffi.h"

#include <csetjmp>

#include "callstate.h"

namespace ffi::cffi
{
constexpr size_t ffiArgSlotsForSize(size_t byteSize)
{
    if (byteSize == 0)
        return 1;

    size_t slots = (byteSize + sizeof(ffi_arg) - 1) / sizeof(ffi_arg);
    return slots == 0 ? 1 : slots;
}
} // namespace ffi::cffi

class CType
{
public:
    static constexpr const char* metatableName = "ctype";

    virtual ~CType() = default;

    ffi_type type;

    virtual int deserialize(lua_State* L, const ffi_arg* data) = 0;
    virtual void serialize(lua_State* L, int index, ffi_arg* to, CallState& state) = 0;
    virtual bool isSymbolPointer() const = 0;
};