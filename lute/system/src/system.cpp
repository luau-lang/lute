#include "lute/system.h"
#include "lua.h"
#include "lualib.h"
#include "uv.h"
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <iterator>
#include <string>
#include <vector>

namespace libsystem
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

        lua_pushinteger(L, static_cast<int>(cpuInfo.speed));
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

constexpr size_t BYTES_PER_MB = 1024 * 1024; // 2^20 bytes

int lua_freememory(lua_State* L)
{
    lua_pushnumber(L, static_cast<double>(uv_get_free_memory()) / BYTES_PER_MB);

    return 1;
}

int lua_totalmemory(lua_State* L)
{
    lua_pushnumber(L, static_cast<double>(uv_get_total_memory()) / BYTES_PER_MB);

    return 1;
}

int lua_hostname(lua_State* L)
{
    size_t sz = 255;
    std::string hostname;
    hostname.reserve(sz);

    int res = uv_os_gethostname(hostname.data(), &sz);
    if (res == UV_ENOBUFS)
    {
        hostname.reserve(sz); // libuv updates the size to what's required
        res = uv_os_gethostname(hostname.data(), &sz);
    }

    if (res != 0)
    {
        luaL_error(L, "libuv error: %s", uv_strerror(res));
    }

    lua_pushstring(L, hostname.c_str());

    return 1;
}

int lua_uptime(lua_State* L)
{
    double uptime = 0;

    int res = uv_uptime(&uptime);
    if (res != 0)
    {
        luaL_error(L, "libuv error: %s", uv_strerror(res));
    }

    lua_pushnumber(L, uptime);

    return 1;
}
} // namespace libsystem

int luaopen_system(lua_State* L)
{
    luteopen_system(L);
    lua_setglobal(L, "system");

    return 1;
}

int luteopen_system(lua_State* L)
{
    lua_createtable(L, 0, std::size(libsystem::lib) + std::size(libsystem::properties));

    for (auto& [name, func] : libsystem::lib)
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
    lua_setfield(L, -2, libsystem::kOperatingSystemProperty);

    lua_pushstring(L, sysinfo.machine);
    lua_setfield(L, -2, libsystem::kArchitectureProperty);

    lua_setreadonly(L, -1, 1);

    return 1;
}
