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

std::optional<int> getEnvironmentVariables(std::map<std::string, std::string>& map)
{
    uv_env_item_t* currentEnvItems;
    int currentEnvCount;
    int err = uv_os_environ(&currentEnvItems, &currentEnvCount);
    if (err != 0)
    {
        uv_os_free_environ(currentEnvItems, currentEnvCount);
        return err;
    }

    for (int i = 0; i < currentEnvCount; i++)
    {
        auto var = currentEnvItems[i];
        if (var.name && var.value && map.find(var.name) == map.end())
            map[var.name] = var.value;
    }
    uv_os_free_environ(currentEnvItems, currentEnvCount);

    return std::nullopt;
}


} // namespace uvutils
