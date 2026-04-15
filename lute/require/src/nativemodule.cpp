#include "lute/nativemodule.h"

#include "lute/common.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include <cctype>
#include <string>

namespace
{

bool hasSuffix(const std::string& path, const char* suffix, size_t len)
{
    return path.size() >= len && path.compare(path.size() - len, len, suffix) == 0;
}

// libgit.dylib → luteopen_git, libmy_utils.so → luteopen_my_utils
std::string resolveEntryPoint(const std::string& path)
{
    size_t lastSlash = path.find_last_of('/');
    std::string filename = (lastSlash != std::string::npos) ? path.substr(lastSlash + 1) : path;

    size_t dot = filename.find_last_of('.');
    if (dot != std::string::npos)
        filename = filename.substr(0, dot);

    if (filename.size() > 3 && filename.substr(0, 3) == "lib")
        filename = filename.substr(3);

    for (char& c : filename)
    {
        if (!std::isalnum(static_cast<unsigned char>(c)) && c != '_')
            c = '_';
    }

    if (!filename.empty() && std::isdigit(static_cast<unsigned char>(filename[0])))
        filename = "_" + filename;

    if (filename.empty())
        filename = "module";

    return "luteopen_" + filename;
}

// Handles are stored in a registry table keyed by module path and
// closed when the lua_State is torn down via userdata destructors.
const char* const kNativeLibs = "_NATIVELIBS";

void anchorLibHandle(lua_State* L, const std::string& path, uv_lib_t lib)
{
    luaL_findtable(L, LUA_REGISTRYINDEX, kNativeLibs, 1);

    uv_lib_t* handle = static_cast<uv_lib_t*>(lua_newuserdatadtor(
        L,
        sizeof(uv_lib_t),
        [](void* ud)
        {
            uv_dlclose(static_cast<uv_lib_t*>(ud));
        }
    ));
    *handle = lib;

    lua_setfield(L, -2, path.c_str());
    lua_pop(L, 1);
}

} // namespace

bool isNativeLibrary(const std::string& path)
{
    return hasSuffix(path, ".dylib", 6) || hasSuffix(path, ".so", 3) || hasSuffix(path, ".dll", 4);
}

int loadNativeModule(lua_State* L, const std::string& path)
{
    luaL_findtable(L, LUA_REGISTRYINDEX, kNativeLibs, 1);
    lua_getfield(L, -1, path.c_str());
    bool alreadyLoaded = !lua_isnil(L, -1);
    lua_pop(L, 2);

    if (alreadyLoaded)
        luaL_errorL(L, "native module '%s' was already loaded", path.c_str());

    uv_lib_t lib;
    if (uv_dlopen(path.c_str(), &lib) != 0)
    {
        std::string err = uv_dlerror(&lib);
        uv_dlclose(&lib);
        luaL_errorL(L, "failed to load native module '%s': %s", path.c_str(), err.c_str());
    }

    std::string entryPoint = resolveEntryPoint(path);

    void* sym;
    if (uv_dlsym(&lib, entryPoint.c_str(), &sym) != 0)
    {
        std::string err = uv_dlerror(&lib);
        uv_dlclose(&lib);
        luaL_errorL(L, "native module '%s' has no entry point '%s': %s", path.c_str(), entryPoint.c_str(), err.c_str());
    }

    auto openFunc = reinterpret_cast<lua_CFunction>(reinterpret_cast<void (*)(void)>(sym));
    if (!openFunc)
    {
        uv_dlclose(&lib);
        luaL_errorL(L, "native module '%s': entry point '%s' resolved to null", path.c_str(), entryPoint.c_str());
    }

    anchorLibHandle(L, path, lib);

    return openFunc(L);
}

std::optional<std::string> readNativeModuleTypes(const std::string& path)
{
    uv_lib_t lib;
    if (uv_dlopen(path.c_str(), &lib) != 0)
    {
        uv_dlclose(&lib);
        return std::nullopt;
    }

    void* sym;
    if (uv_dlsym(&lib, "lute_types", &sym) != 0 || !sym)
    {
        uv_dlclose(&lib);
        return std::nullopt;
    }

    std::string types(static_cast<const char*>(sym));
    uv_dlclose(&lib);
    return types;
}
