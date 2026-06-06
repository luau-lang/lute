#include "lute/nativemodule.h"

#include "lute/common.h"

#include "lua.h"
#include "lualib.h"

#include "uv.h"

#include <string>
#include <string_view>
#include <unordered_map>

namespace
{

// Bumped when the native-extension entry-point or required-symbol contract changes.
constexpr int kLuteNativeModuleAbiVersion = 1;

// path -> handle, scoped per main-thread lua_State. Libs are dlclose'd from
// releaseNativeModules which the runtime calls AFTER lua_close returns; by then every
// userdata dtor has already run with the lib still mapped, so dtors implemented in the
// extension's own text segment unwind safely.
std::unordered_map<lua_State*, std::unordered_map<std::string, uv_lib_t>>& nativeLibCache()
{
    static std::unordered_map<lua_State*, std::unordered_map<std::string, uv_lib_t>> cache;
    return cache;
}

bool hasSuffix(std::string_view str, std::string_view suffix)
{
    return str.size() >= suffix.size() && str.substr(str.size() - suffix.size()) == suffix;
}

// libhello.dylib -> luteopen_hello (POSIX linker convention adds the "lib" prefix).
// hello.dll    -> luteopen_hello (Windows has no automatic prefix).
std::string resolveEntryPoint(const std::string& path)
{
    size_t lastSlash = path.find_last_of("/\\");
    std::string filename = (lastSlash != std::string::npos) ? path.substr(lastSlash + 1) : path;

    std::string_view matchedSuffix;
    for (std::string_view suffix : kNativeSuffixes)
    {
        if (hasSuffix(filename, suffix))
        {
            filename.resize(filename.size() - suffix.size());
            matchedSuffix = suffix;
            break;
        }
    }

    bool isPosixLib = matchedSuffix == ".so" || matchedSuffix == ".dylib";
    if (isPosixLib && filename.size() > 3 && filename.compare(0, 3, "lib") == 0)
        filename.erase(0, 3);

    return "luteopen_" + filename;
}

} // namespace

bool isNativeModule(const std::string& path)
{
    for (std::string_view suffix : kNativeSuffixes)
    {
        if (hasSuffix(path, suffix))
            return true;
    }
    return false;
}

int loadNativeModule(lua_State* L, const std::string& path)
{
    auto& libs = nativeLibCache()[lua_mainthread(L)];

    auto it = libs.find(path);
    if (it == libs.end())
    {
        uv_lib_t lib;
        if (uv_dlopen(path.c_str(), &lib) != 0)
        {
            std::string err = uv_dlerror(&lib);
            // libuv's uv_dlclose guards on a null handle, so this is safe after a failed
            // open and frees the errmsg storage.
            uv_dlclose(&lib);
            luaL_errorL(L, "failed to load native module '%s': %s", path.c_str(), err.c_str());
        }

        void* versionSym;
        if (uv_dlsym(&lib, "lute_module_abi_version", &versionSym) != 0 || !versionSym)
        {
            uv_dlclose(&lib);
            luaL_errorL(L, "native module '%s' is missing 'lute_module_abi_version'", path.c_str());
        }

        int version = *static_cast<const int*>(versionSym);
        if (version != kLuteNativeModuleAbiVersion)
        {
            uv_dlclose(&lib);
            luaL_errorL(
                L,
                "native module '%s' has incompatible ABI version (got %d, expected %d)",
                path.c_str(),
                version,
                kLuteNativeModuleAbiVersion
            );
        }

        it = libs.emplace(path, lib).first;
    }

    std::string entryPoint = resolveEntryPoint(path);

    void* sym;
    if (uv_dlsym(&it->second, entryPoint.c_str(), &sym) != 0 || !sym)
    {
        std::string err = uv_dlerror(&it->second);
        luaL_errorL(L, "native module '%s' has no entry point '%s': %s", path.c_str(), entryPoint.c_str(), err.c_str());
    }

    auto openFunc = reinterpret_cast<lua_CFunction>(reinterpret_cast<void (*)(void)>(sym));
    return openFunc(L);
}

void releaseNativeModules(lua_State* L)
{
    auto& cache = nativeLibCache();
    auto it = cache.find(L);
    if (it == cache.end())
        return;
    for (auto& [path, lib] : it->second)
        uv_dlclose(&lib);
    cache.erase(it);
}

// Looks up a `lute_types` string symbol exported from the binary. dlopen runs static
// initializers in the extension and its transitive dynamic dependencies — that's the
// known cost of single-artifact distribution, accepted in exchange for not maintaining
// a sidecar file or a per-format binary parser. dlclose is safe here because we don't
// retain anything (no Lua values, no function pointers) past the read.
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
