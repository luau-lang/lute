#pragma once

#include "lua.h"

namespace ffi::cffi
{
    /// Loads a dynamic library and its symbols into Luau based off a table of symbol names and types.
    int loadLibrary(lua_State* L);
}
