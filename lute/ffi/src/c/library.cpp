#include "functions.h"
#include "uv.h"
#include "lua.h"
#include "lualib.h"

#include "library.h"
#include "types.h"

namespace ffi::cffi
{

int load_library(lua_State* L)
{
    const char* lib_path = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    lua_settop(L, 2);

    lua_createtable(L, 0, 0);

    uv_lib_t lib;
    if (uv_dlopen(lib_path, &lib) != 0)
    {
        luaL_error(L, "Failed to load library '%s': %s", lib_path, uv_dlerror(&lib));
    }

    lua_pushnil(L);
    while (lua_next(L, 2) != 0)
    {
        const char* sym = luaL_checkstring(L, -2);
        void (*sym_ptr)();

        if (uv_dlsym(&lib, sym, reinterpret_cast<void**>(&sym_ptr)) != 0)
        {
            luaL_error(L, "Failed to load symbol '%s': %s", sym, uv_dlerror(&lib));
        }

        auto* type = static_cast<CType*>(luaL_checkudata(L, -1, "ctype"));

        auto* func_type = dynamic_cast<CFunctionType*>(type);
        if (!func_type)
        {
            luaL_error(L, "Expected function type for symbol '%s'", sym);
        }

        CFunction function{sym_ptr, std::move(func_type->functionInfo)};
        function.pushCFunction(L, sym_ptr, sym);
        
        lua_setfield(L, 3, sym);

        lua_pop(L, 1);
    }

    return 1;
}

} // namespace ffi::cffi
