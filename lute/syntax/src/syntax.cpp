#include "lute/syntax.h"

#include "lute/common.h"

#include <iterator>

namespace luau
{
struct Span
{
    uint32_t beginLine;
    uint32_t beginColumn;
    uint32_t endLine;
    uint32_t endColumn;
};

static Span checkSpan(lua_State* L, int index)
{
    lua_checkstack(L, 1);

    if (!lua_istable(L, index))
        luaL_typeerror(L, index, "span");

    if (lua_getfield(L, index, "beginLine") == LUA_TNIL)
        luaL_typeerror(L, index, "span");
    int beginLine = lua_tonumber(L, -1);
    lua_pop(L, 1);

    if (lua_getfield(L, index, "beginColumn") == LUA_TNIL)
        luaL_typeerror(L, index, "span");
    int beginColumn = lua_tonumber(L, -1);
    lua_pop(L, 1);

    if (lua_getfield(L, index, "endLine") == LUA_TNIL)
        luaL_typeerror(L, index, "span");
    int endLine = lua_tonumber(L, -1);
    lua_pop(L, 1);

    if (lua_getfield(L, index, "endColumn") == LUA_TNIL)
        luaL_typeerror(L, index, "span");
    int endColumn = lua_tonumber(L, -1);
    lua_pop(L, 1);

    return {static_cast<uint32_t>(beginLine), static_cast<uint32_t>(beginColumn), static_cast<uint32_t>(endLine), static_cast<uint32_t>(endColumn)};
}

static int createSpan(lua_State* L)
{
    lua_checkstack(L, 2);

    // check that the argument is compliant with the span interface!
    Span span = checkSpan(L, 1);

    lua_createtable(L, 0, 4);

    lua_pushinteger(L, span.beginLine);
    lua_setfield(L, -2, "beginLine");

    lua_pushinteger(L, span.beginColumn);
    lua_setfield(L, -2, "beginColumn");

    lua_pushinteger(L, span.endLine);
    lua_setfield(L, -2, "endLine");

    lua_pushinteger(L, span.endColumn);
    lua_setfield(L, -2, "endColumn");

    luaL_getmetatable(L, kSpanType);
    lua_setmetatable(L, -2);

    lua_setreadonly(L, -1, 1);

    return 1;
}

int ltSpan(lua_State* L)
{
    Span lhs = checkSpan(L, 1);
    Span rhs = checkSpan(L, 2);

    lua_checkstack(L, 2);

    // Compare beginnings, and if they're equal, compare ends
    if (lhs.beginLine < rhs.beginLine || (lhs.beginLine == rhs.beginLine && lhs.beginColumn < rhs.beginColumn))
        lua_pushboolean(L, 1);
    else if (lhs.beginLine == rhs.beginLine && lhs.beginColumn == rhs.beginColumn)
    {
        if (lhs.endLine < rhs.endLine || (lhs.endLine == rhs.endLine && lhs.endColumn < rhs.endColumn))
            lua_pushboolean(L, 1);
        else
            lua_pushboolean(L, 0);
    }
    else
        lua_pushboolean(L, 0);

    return 1;
}

static int makeSpanLibrary(lua_State* L)
{
    lua_checkstack(L, 2);

    lua_createtable(L, 0, 1);

    lua_pushcfunction(L, createSpan, "create");
    lua_setfield(L, -2, "create");

    lua_setreadonly(L, -1, 1);

    if (luaL_newmetatable(L, kSpanType))
    {
        lua_pushcfunction(L, luau::ltSpan, "span.__lt");
        lua_setfield(L, -2, "__lt");

        lua_setreadonly(L, -1, 1);
    }

    lua_pop(L, 1);

    return 1;
}

} // namespace luau

const luaL_Reg Syntax::lib[] = {{nullptr, nullptr}};

const char* const Syntax::properties[] = {"cst", luau::kSpanType};

int Syntax::pushLibrary(lua_State* L)
{
    lua_createtable(L, 0, std::size(Syntax::lib) + std::size(Syntax::properties));

    lua_createtable(L, 0, 0);
    lua_setreadonly(L, -1, 1);

    lua_setfield(L, -2, "cst");

    luau::makeSpanLibrary(L);
    lua_setfield(L, -2, luau::kSpanType);

    lua_setreadonly(L, -1, 1);
    return 1;
}

LUTE_API int luaopen_syntax(lua_State* L)
{
    return Syntax::openAsGlobal(L);
}

LUTE_API int luteopen_syntax(lua_State* L)
{
    return Syntax::pushLibrary(L);
}
