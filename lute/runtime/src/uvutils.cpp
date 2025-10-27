#include "lute/uvutils.h"

#include "uv.h"

namespace uvutils
{

UvError::UvError(int code)
    : code(code)
{
}

std::string UvError::toString() const
{
    return uv_strerror(code);
}

Luau::Variant<std::string, UvError> getStringFromUv(BufferWriter bufferWriter, size_t initialBufferSize)
{
    std::string buffer;
    size_t size = initialBufferSize;
    buffer.resize(size);

    int writeStatus = bufferWriter(buffer.data(), &size);
    if (writeStatus == UV_ENOBUFS)
    {
        // `size` now contains the required size
        buffer.resize(size);
        writeStatus = bufferWriter(buffer.data(), &size);
    }

    if (writeStatus < 0)
        return UvError{writeStatus};

    buffer.resize(size);
    return buffer;
}

} // namespace uvutils
