#pragma once

#include <cstddef>
#include <string>

namespace uvutils
{

struct StringResult
{
    int status = 0;
    std::string value;
};

typedef int (*BufferWriter)(char* buffer, size_t* size);

// Abstracts away buffer management when getting strings from libuv functions.
StringResult getStringFromUv(BufferWriter bufferWriter, size_t initialBufferSize = 256);

} // namespace uvutils
