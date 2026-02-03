#pragma once

#include "Luau/Variant.h"

#include <cstddef>
#include <string>

#define LUTE_ASSERT(expr) LUAU_ASSERT(expr)

namespace uvutils
{

struct UvError
{
    UvError(int code);
    std::string toString() const;

    int code;
};

typedef int (*BufferWriter)(char* buffer, size_t* size);

// Abstracts away buffer management when getting strings from libuv functions.
Luau::Variant<std::string, UvError> getStringFromUv(BufferWriter bufferWriter, size_t initialBufferSize = 256);

} // namespace uvutils
