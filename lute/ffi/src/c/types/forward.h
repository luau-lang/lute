#pragma once

#include "lua.h"

namespace ffi::cffi
{

// Forward declarations for type system
class CType;
class PrimitiveCType;
class CFunctionType;
class CFunction;
class StructCType;
class CConstant;

// API functions
int newCFunction(lua_State* L);
int newCStruct(lua_State* L);
int newCConstant(lua_State* L);

} // namespace ffi::cffi
