#pragma once

#include <utility>

#include "types.h"

namespace ffi::cffi
{

class CConstant : public CType
{
public:
    explicit CConstant(UserdataReference<CType> newInnerType)
        : innerType{std::move(newInnerType)}
    {
        type = this->innerType->type;
    }

private:
    UserdataReference<CType> innerType;

    int deserialize(lua_State* L, const ffi_arg* data) override;
    void serialize(lua_State* L, int index, ffi_arg* to, CallState& state) override;
    bool isSymbolPointer() const override { return innerType->isSymbolPointer(); }
};

} // namespace ffi::cffi
