#include "lute/luau.h"

#include "Luau/Compiler.h"

#include "lua.h"
#include "lualib.h"
#include <cstddef>
#include <cstring>
#include <iterator>

namespace luau
{
inline int check_int_field(lua_State* L, int obj_idx, const char* field_name, int default_value)
{
    if (lua_getfield(L, obj_idx, field_name) == LUA_TNIL)
        return default_value;

    int is_num;
    int value = lua_tointegerx(L, -1, &is_num);

    if (!is_num)
        luaL_errorL(L, "Expected number for field \"%s\"", field_name);

    return value;
}

int compile_luau(lua_State* L)
{
    size_t source_size;
    const char* source = luaL_checklstring(L, 1, &source_size);

    Luau::CompileOptions opts{};

    if (lua_type(L, 2) == LUA_TTABLE)
    {
        opts.optimizationLevel = check_int_field(L, 2, "optimization_level", 1);
        opts.debugLevel = check_int_field(L, 2, "debug_level", 1);
        opts.coverageLevel = check_int_field(L, 2, "coverage_level", 1);
    }

    std::string bytecode = Luau::compile(std::string(source, source_size), opts);

    std::string* userdata = static_cast<std::string*>(lua_newuserdata(L, sizeof(std::string)));

    new (userdata) std::string(std::move(bytecode));

    luaL_getmetatable(L, kCompilerResultType);
    lua_setmetatable(L, -2);

    return 1;
}

int load_luau(lua_State* L)
{
    const std::string* bytecode_string = static_cast<std::string*>(luaL_checkudata(L, 1, kCompilerResultType));
    const char* chunk_name = luaL_optlstring(L, 2, "luau.load", nullptr);

    luau_load(L, chunk_name, bytecode_string->c_str(), bytecode_string->length(), lua_gettop(L) > 2 ? 3 : 0);

    return 1;
}

} // namespace luau

static int index_result(lua_State* L)
{
    const std::string* bytecode_string = static_cast<std::string*>(luaL_checkudata(L, 1, kCompilerResultType));

    if (std::strcmp(luaL_checkstring(L, 2), "bytecode") == 0)
    {
        lua_pushlstring(L, bytecode_string->c_str(), bytecode_string->size());

        return 1;
    }

    return 0;
}

// perform type mt registration, etc
static int init_luau_lib(lua_State* L)
{
    luaL_newmetatable(L, kCompilerResultType);

    lua_pushcfunction(L, index_result, "CompilerResult.__index");
    lua_setfield(L, -2, "__index");

    lua_pop(L, 1);

    return 1;
}

int luaopen_luau(lua_State* L)
{
    luaL_register(L, "luau", luau::lib);

    return init_luau_lib(L);
}

int luteopen_luau(lua_State* L)
{
    lua_createtable(L, 0, std::size(luau::lib));

    for (auto& [name, func] : luau::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    return init_luau_lib(L);
}
