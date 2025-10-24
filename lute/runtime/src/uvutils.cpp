#include "lute/uvutils.h"

#include "uv.h"

namespace uvutils
{

StringResult getStringFromUv(BufferWriter bufferWriter, size_t initialBufferSize)
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
        return StringResult{writeStatus, ""};

    buffer.resize(size);
    return StringResult{writeStatus, std::move(buffer)};
}

} // namespace uvutils
