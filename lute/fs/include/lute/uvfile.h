#pragma once

#include <cstddef>
#include <optional>

struct lua_State;

namespace fs
{

struct UVFile
{
    std::optional<int> fd = std::nullopt;
};

// Writes `numBytes` from `toWrite` to `handle` and yields until the write completes.
// `handle` must stay alive until the calling thread resumes.
int write_impl(lua_State* L, UVFile* handle, const char* toWrite, size_t numBytes);

} // namespace fs
