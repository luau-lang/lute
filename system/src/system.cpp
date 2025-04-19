#include "lute/system.h"
#include "lua.h"
#include <iterator>

#ifdef _WIN32
#include <windows.h>
#else
#include <sys/utsname.h>
#endif

int luaopen_system()
{
    return 0;
}

int luteopen_system(lua_State* L)
{
    lua_createtable(L, 0, std::size(system_lib::lib));

    for (auto& [name, func] : system_lib::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

#ifdef _WIN32
    lua_pushstring(L, "Windows");
    lua_setfield(L, -2, "os");

    SYSTEM_INFO sysinfo;
    GetSystemInfo(&sysinfo);

    if (sysinfo.wProcessorArchitecture == PROCESSOR_ARCHITECTURE_AMD64)
        lua_pushstring(L, "x64");
    else if (sysinfo.wProcessorArchitecture == PROCESSOR_ARCHITECTURE_ARM)
        lua_pushstring(L, "ARM");
    else if (sysinfo.wProcessorArchitecture == PROCESSOR_ARCHITECTURE_ARM64)
        lua_pushstring(L, "ARM64");
    else if (sysinfo.wProcessorArchitecture == PROCESSOR_ARCHITECTURE_INTEL)
        lua_pushstring(L, "x86");
    else if (sysinfo.wProcessorArchitecture == PROCESSOR_ARCHITECTURE_UNKNOWN)
        lua_pushstring(L, "unknown");

    lua_setfield(L, -2, "arch");

    lua_pushinteger(L, (uint64_t)sysinfo.dwNumberOfProcessors);
    lua_setfield(L, -2, "threads");
#elif
    // TODO: linux + macos using uname.h
#endif

    lua_setreadonly(L, -1, 1);

    return 1;
}

namespace system_lib
{

}
