#include "lute/vm.h"

#include "lute/runtime.h"

const char* const VM::properties[] = {};

const luaL_Reg VM::lib[] = {
    {"create", VM::lua_spawn},
    {nullptr, nullptr},
};

int VM::pushLibrary(lua_State* L)
{
    lua_createtable(L, 0, std::size(VM::lib));

    for (auto& [name, func] : VM::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    return 1;
}

int luaopen_vm(lua_State* L)
{
    return VM::openAsGlobal(L);
}

int luteopen_vm(lua_State* L)
{
    return VM::pushLibrary(L);
}
