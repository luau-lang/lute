#include "lute/luau.h"

#include "lute/common.h"
#include "lute/configresolver.h"
#include "lute/runtime.h"
#include "lute/tcmoduleresolver.h"
#include "lute/type.h"

#include "Luau/Ast.h"
#include "Luau/BuiltinDefinitions.h"
#include "Luau/Compiler.h"
#include "Luau/Frontend.h"
#include "Luau/Location.h"
#include "Luau/NotNull.h"
#include "Luau/ParseOptions.h"
#include "Luau/Parser.h"
#include "Luau/ParseResult.h"
#include "Luau/ToString.h"

#include "lua.h"
#include "lualib.h"

#include <cstddef>
#include <cstring>
#include <iterator>
#include <memory>
#include <string>

namespace luau
{

static constexpr const char kCompileResultType[] = "CompileResult";

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
        opts.optimizationLevel = check_int_field(L, 2, "optimizationlevel", 1);
        opts.debugLevel = check_int_field(L, 2, "debuglevel", 1);
        opts.coverageLevel = check_int_field(L, 2, "coveragelevel", 1);
    }

    std::string bytecode = Luau::compile(std::string(source, source_size), opts);

    std::string* userdata = static_cast<std::string*>(lua_newuserdatadtor(
        L,
        sizeof(std::string),
        [](void* ptr)
        {
            std::destroy_at(static_cast<std::string*>(ptr));
        }
    ));

    new (userdata) std::string(std::move(bytecode));

    luaL_getmetatable(L, kCompileResultType);
    lua_setmetatable(L, -2);

    return 1;
}

static int indexCompileResult(lua_State* L)
{
    const std::string* bytecode_string = static_cast<std::string*>(luaL_checkudata(L, 1, kCompileResultType));

    if (std::strcmp(luaL_checkstring(L, 2), "bytecode") == 0)
    {
        lua_pushlstring(L, bytecode_string->c_str(), bytecode_string->size());

        return 1;
    }

    return 0;
}

int load_luau(lua_State* L)
{
    const std::string* bytecodeString = static_cast<std::string*>(luaL_checkudata(L, 1, kCompileResultType));
    const char* chunkname = luaL_checkstring(L, 2);
    int envIndex = lua_isnoneornil(L, 3) ? 0 : 3;

    if (luau_load(L, chunkname, bytecodeString->c_str(), bytecodeString->length(), envIndex) != 0)
        lua_error(L);

    return 1;
}

int typeofModule_luau(lua_State* L)
{
    std::string modulePath = luaL_checkstring(L, 1);

    Luau::LuteTypeCheckModuleResolver moduleResolver{getRuntime(L)->reporter};
    Luau::LuteConfigResolver configResolver(Luau::Mode::NoCheck);
    Luau::FrontendOptions fopts;
    fopts.retainFullTypeGraphs = true;

    Luau::Frontend frontend(&moduleResolver, &configResolver, fopts);
    Luau::registerBuiltinGlobals(frontend, frontend.globals);
    Luau::freeze(frontend.globals.globalTypes);

    frontend.check(modulePath);

    Luau::ModulePtr modulePtr = frontend.moduleResolver.getModule(modulePath);
    if (!modulePtr)
    {
        lua_pushnil(L);
        return 1;
    }

    // Serialize and push the return type
    serializeTypePack(L, modulePtr->returnType);

    return 1;
}

// perform type mt registration, etc
static int initLuauLibrary(lua_State* L)
{
    luaL_newmetatable(L, kCompileResultType);

    // Set __type
    lua_pushstring(L, kCompileResultType);
    lua_setfield(L, -2, "__type");

    lua_pushcfunction(L, luau::indexCompileResult, "CompilerResult.__index");
    lua_setfield(L, -2, "__index");

    lua_setreadonly(L, -1, 1);

    lua_pop(L, 1);

    return 1;
}

} // namespace luau

const char* const LuauLib::properties[] = {nullptr};

const luaL_Reg LuauLib::lib[] = {
    {"compile", luau::compile_luau},
    {"load", luau::load_luau},
    {"resolveModule", resolveModule_luau},
    {"typeofModule", luau::typeofModule_luau},
    {nullptr, nullptr},
};

int LuauLib::pushLibrary(lua_State* L)
{
    lua_createtable(L, 0, std::size(LuauLib::lib) + std::size(LuauLib::properties));

    for (auto& [name, func] : LuauLib::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    return luau::initLuauLibrary(L);
}

LUTE_API int luaopen_luau(lua_State* L)
{
    return LuauLib::openAsGlobal(L);
}

LUTE_API int luteopen_luau(lua_State* L)
{
    return LuauLib::pushLibrary(L);
}
