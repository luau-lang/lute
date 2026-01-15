#pragma once

#include <optional>

struct lua_State;

namespace fs
{

struct UVFile
{
    std::optional<int> fd = std::nullopt;
};

// New fs operations using UVRequest abstraction
int open_impl(lua_State* L, const char* path, int flags, int mode);
int read_impl(lua_State* L, UVFile* handle);
int write_impl(lua_State* L, UVFile* handle, const char* toWrite, size_t numBytes);
int close_impl(lua_State* L, UVFile* handle);
int remove_impl(lua_State* L, const char* path);
int mkdir_impl(lua_State* L, const char* path, int mode);
} // namespace fs
