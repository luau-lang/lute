#include "lute/system.h"
#include "lua.h"
#include "uv.h"
#include <iterator>
#include <string>
#include <vector>

int luaopen_system(lua_State* L)
{
    luteopen_system(L);
    lua_setglobal(L, "system");

    return 1;
}

int luteopen_system(lua_State* L)
{
    lua_createtable(L, 0, std::size(system_lib::lib) + std::size(system_lib::properties));

    for (auto& [name, func] : system_lib::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    // os
    uv_utsname_t sysinfo;
    uv_os_uname(&sysinfo);

    lua_pushstring(L, sysinfo.sysname);
    lua_setfield(L, -2, kOperatingSystemProperty);

    lua_pushstring(L, sysinfo.machine);
    lua_setfield(L, -2, kArchitectureProperty);

    lua_setreadonly(L, -1, 1);

    return 1;
}

namespace system_lib
{
int lua_cpus(lua_State* L)
{
    int count = uv_available_parallelism();
    uv_cpu_info_t* cpus;

    uv_cpu_info(&cpus, &count);

    lua_createtable(L, count, 0);

    int j = 0;
    for (int i = 0; i < count; i++)
    {
        lua_pushinteger(L, ++j);

        auto cpuInfo = cpus[i];

        // model, speed, times
        lua_createtable(L, 0, 2);

        lua_pushstring(L, cpuInfo.model);
        lua_setfield(L, -2, "model");

        lua_pushinteger(L, (int)cpuInfo.speed);
        lua_setfield(L, -2, "speed");

        // sys, user, idle, irq, nice
        lua_createtable(L, 0, 5);

        // cast to double cuz uint64 has higher max n and lua numbers are 52bit
        lua_pushnumber(L, static_cast<double>(cpuInfo.cpu_times.sys));
        lua_setfield(L, -2, "sys");

        lua_pushnumber(L, static_cast<double>(cpuInfo.cpu_times.idle));
        lua_setfield(L, -2, "idle");

        lua_pushnumber(L, static_cast<double>(cpuInfo.cpu_times.irq));
        lua_setfield(L, -2, "irq");

        lua_pushnumber(L, static_cast<double>(cpuInfo.cpu_times.nice));
        lua_setfield(L, -2, "nice");

        lua_pushnumber(L, static_cast<double>(cpuInfo.cpu_times.user));
        lua_setfield(L, -2, "user");

        lua_setfield(L, -2, "times");

        lua_settable(L, -3);
    };

    return 1;
}

int lua_threadcount(lua_State* L)
{
    lua_pushinteger(L, uv_available_parallelism());

    return 1;
}

} // namespace system_lib
