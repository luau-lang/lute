#pragma once

#include "zlib.h"

#include <cstddef>
#include <limits>
#include <optional>
#include <string>
#include <string_view>

struct EmbeddedModule
{
    std::string_view path;
    std::string_view compressedContents;
    std::size_t uncompressedSize = 0;
    bool isDirectory = false;
};

inline std::optional<std::string> decompressEmbeddedModule(const EmbeddedModule& module)
{
    if (module.isDirectory)
        return std::nullopt;

    if (module.compressedContents.size() > std::numeric_limits<uInt>::max() || module.uncompressedSize > std::numeric_limits<uInt>::max())
        return std::nullopt;

    std::string result(module.uncompressedSize, '\0');

    z_stream stream{};
    stream.next_in = reinterpret_cast<Bytef*>(const_cast<char*>(module.compressedContents.data()));
    stream.avail_in = static_cast<uInt>(module.compressedContents.size());
    stream.next_out = reinterpret_cast<Bytef*>(result.data());
    stream.avail_out = static_cast<uInt>(result.size());

    if (inflateInit2(&stream, MAX_WBITS + 16) != Z_OK)
        return std::nullopt;

    int status = inflate(&stream, Z_FINISH);
    inflateEnd(&stream);

    if (status != Z_STREAM_END || stream.total_out != module.uncompressedSize)
        return std::nullopt;

    return result;
}
