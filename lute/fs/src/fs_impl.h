#pragma once

#include <optional>
#include <string_view>

struct lua_State;

namespace fs
{

constexpr char UV_TYPENAME_UNKNOWN[] = "unknown"; // UV_DIRENT_UNKNOWN
constexpr char UV_TYPENAME_FILE[] = "file";       // UV_DIRENT_FILE
constexpr char UV_TYPENAME_DIR[] = "dir";         // UV_DIRENT_DIR
constexpr char UV_TYPENAME_LINK[] = "link";       // UV_DIRENT_LINK
constexpr char UV_TYPENAME_FIFO[] = "fifo";       // UV_DIRENT_FIFO
constexpr char UV_TYPENAME_SOCKET[] = "socket";   // UV_DIRENT_SOCKET
constexpr char UV_TYPENAME_CHAR[] = "char";       // UV_DIRENT_CHAR
constexpr char UV_TYPENAME_BLOCK[] = "block";     // UV_DIRENT_BLOCK

constexpr const char* UV_DIRENT_TYPES[] = {
    UV_TYPENAME_UNKNOWN,
    UV_TYPENAME_FILE,
    UV_TYPENAME_DIR,
    UV_TYPENAME_LINK,
    UV_TYPENAME_FIFO,
    UV_TYPENAME_SOCKET,
    UV_TYPENAME_CHAR,
    UV_TYPENAME_BLOCK,
};

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
int stat_impl(lua_State* L, const char* path);
int type_impl(lua_State* L, const char* path);

int mkdir_impl(lua_State* L, const char* path, int mode);
} // namespace fs
