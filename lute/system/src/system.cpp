#include "lute/system.h"

#include "lute/uvutils.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <iterator>
#include <string>

namespace libsystem
{

static const char kArchitectureProperty[] = "arch";
static const char kOperatingSystemProperty[] = "os";

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
    auto result = uvutils::getStringFromUv(uv_os_gethostname);
    if (uvutils::UvError* error = result.get_if<uvutils::UvError>())
        luaL_error(L, "failed to get hostname: %s", error->toString().c_str());

    std::string* hostname = result.get_if<std::string>();
    lua_pushlstring(L, hostname->c_str(), hostname->size());
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

int lua_tmpdir(lua_State* L)
{
    auto result = uvutils::getStringFromUv(uv_os_tmpdir);
    if (uvutils::UvError* error = result.get_if<uvutils::UvError>())
        luaL_error(L, "failed to get temporary directory: %s", error->toString().c_str());

    std::string* tmpDir = result.get_if<std::string>();
    lua_pushlstring(L, tmpDir->c_str(), tmpDir->size());
    return 1;
}
} // namespace libsystem

static const std::string properties[] = {
    libsystem::kArchitectureProperty,
    libsystem::kOperatingSystemProperty,
};

const luaL_Reg System::lib[] = {
    {"cpus", libsystem::lua_cpus},
    {"threadCount", libsystem::lua_threadcount},
    {"freeMemory", libsystem::lua_freememory},
    {"totalMemory", libsystem::lua_totalmemory},
    {"hostName", libsystem::lua_hostname},
    {"uptime", libsystem::lua_uptime},
    {"tmpdir", libsystem::lua_tmpdir},
    {nullptr, nullptr},
};

int System::pushLibrary(lua_State* L)
{
    lua_createtable(L, 0, std::size(System::lib) + std::size(properties));

    for (auto& [name, func] : System::lib)
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

int luaopen_system(lua_State* L)
{
    return System::openAsGlobal(L);
}

int luteopen_system(lua_State* L)
{
    return System::pushLibrary(L);
}
