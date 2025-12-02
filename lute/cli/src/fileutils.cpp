// This file is part of the Lute programming language and is licensed under MIT License
#include "lute/fileutils.h"

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <direct.h>
#include <windows.h>
#else
#include <unistd.h>

#include <sys/stat.h>
#endif

#include <cstring>
#include "Luau/FileUtils.h"

namespace Lute
{

#ifdef _WIN32
static std::wstring fromUtf8(const std::string& path)
{
    if (path.empty())
        return std::wstring();

    size_t result = MultiByteToWideChar(CP_UTF8, 0, path.data(), int(path.size()), nullptr, 0);
    if (result == 0)
        return std::wstring();

    std::wstring buf(result, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, path.data(), int(path.size()), &buf[0], int(buf.size()));

    return buf;
}
#endif

FILE* openFile(const std::string& path, const char* mode)
{
#ifdef _WIN32
    std::wstring wpath = fromUtf8(path);
    std::wstring wmode = fromUtf8(mode);
    if (wpath.empty() || wmode.empty())
        return nullptr;
    return _wfopen(wpath.c_str(), wmode.c_str());
#else
    return fopen(path.c_str(), mode);
#endif
}

bool writeFile(const std::string& path, const std::string& content)
{
    FILE* file = openFile(path, "wb");
    if (!file)
        return false;

    bool success = fwrite(content.data(), 1, content.size(), file) == content.size();
    fclose(file);
    return success;
}

bool createDirectory(const std::string& path)
{
#ifdef _WIN32
    std::wstring wpath = fromUtf8(path);
    if (wpath.empty())
        return false;
    return _wmkdir(wpath.c_str()) == 0 || errno == EEXIST;
#else
    return mkdir(path.c_str(), 0755) == 0 || errno == EEXIST;
#endif
}

bool createDirectories(const std::string& path)
{
    if (path.empty())
        return false;

    std::vector<std::string_view> components = splitPath(path);
    std::string currentPath;
    size_t offset = 0;

    // Handle absolute paths - extract the root/prefix
    if (isAbsolutePath(path))
    {
#ifdef _WIN32
        // Check if path starts with drive letter (e.g., "C:")
        if (path.size() >= 2 && path[1] == ':')
        {
            currentPath = path.substr(0, 2);
            offset = 1; // Skip the drive letter component in the loop
        }
        else if (path.size() >= 1 && (path[0] == '/' || path[0] == '\\'))
        {
            currentPath = path.substr(0, 1);
        }
#else
        currentPath = "/";
#endif
    }

    for (size_t i = offset; i < components.size(); ++i)
    {
        const std::string_view component = components[i];
        currentPath = joinPaths(currentPath, component);

        if (!createDirectory(currentPath))
        {
            // Check if the directory already exists
            if (errno != EEXIST)
                return false;
        }
    }

    return true;
}

bool removeFile(const std::string& path)
{
#ifdef _WIN32
    std::wstring wpath = fromUtf8(path);
    if (wpath.empty())
        return false;
    return _wunlink(wpath.c_str()) == 0;
#else
    return unlink(path.c_str()) == 0;
#endif
}

bool removeDirectory(const std::string& path)
{
#ifdef _WIN32
    std::wstring wpath = fromUtf8(path);
    if (wpath.empty())
        return false;
    return _wrmdir(wpath.c_str()) == 0;
#else
    return rmdir(path.c_str()) == 0;
#endif
}

} // namespace Lute
