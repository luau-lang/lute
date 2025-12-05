#pragma once

#include "types.h"

#include <memory>
#include <tuple>
#include <utility>
#include <vector>

namespace ffi::cffi
{

class StructCType : public CType
{
public:
    StructCType(std::vector<std::pair<std::string, UserdataReference<CType>>> inFields)
        : fields{std::move(inFields)}
    {
        size_t fieldCount = fields.size();

        elementTypePointers = std::make_unique<ffi_type*[]>(fieldCount + 1);
        elementOffsets = std::make_unique<size_t[]>(fieldCount);

        for (size_t i = 0; i < fieldCount; ++i)
        {
            elementTypePointers[i] = &std::get<1>(fields[i])->type;
        }
        
        elementTypePointers[fieldCount] = nullptr;

        type.type = FFI_TYPE_STRUCT;
        type.size = 0;
        type.alignment = 0;
        type.elements = elementTypePointers.get();

        ffi_get_struct_offsets(FFI_DEFAULT_ABI, &type, elementOffsets.get());
    }

    int deserialize(lua_State* L, const ffi_arg* data) override;
    void serialize(lua_State* L, int index, ffi_arg* to, CallState& state) override;

private:
    std::unique_ptr<size_t[]> elementOffsets;
    std::unique_ptr<ffi_type*[]> elementTypePointers;
    std::vector<std::pair<std::string, UserdataReference<CType>>> fields;
};

} // namespace ffi::cffi
