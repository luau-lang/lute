#pragma once

#include "lute/library.h"

#include "lua.h"
#include "lualib.h"

namespace luau
{
static constexpr const char kSpanType[] = "span"; // Uncapitalized because the span library lives under `cst.{kSpanType}`
static constexpr const char kCstPunctuatedType[] = "CstPunctuated";

int ltSpan(lua_State* L);
} // namespace luau

// open the library as a standard global luau library
LUTE_API int luaopen_syntax_parser(lua_State* L);
// open the library as a table on top of the stack
LUTE_API int luteopen_syntax_parser(lua_State* L);

// open the library as a standard global luau library
LUTE_API int luaopen_syntax(lua_State* L);
// open the library as a table on top of the stack
LUTE_API int luteopen_syntax(lua_State* L);

struct SyntaxParser : LuteLibrary<SyntaxParser>
{
    static constexpr const char kName[] = "syntax.parser";
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
    static const char* const properties[];
};

struct Syntax : LuteLibrary<Syntax>
{
    static constexpr const char kName[] = "syntax";
    static int pushLibrary(lua_State* L);
    static const luaL_Reg lib[];
    static const char* const properties[];
};
