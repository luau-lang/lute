#include "lute/libraryvfs.h"

#include "Luau/Common.h"
#include "lute/modulepath.h"

#include "Luau/FileUtils.h"

#include <optional>
#include <string>

namespace Library
{

static std::string generateRootLuaurc(const std::vector<Identifier>& dependencies)
{
    std::string rootLuaurc = "{\n    \"aliases\": {\n";
    for (const Identifier& dep : dependencies)
    {
        rootLuaurc += "        \"" + dep.name + "\": \"$" + dep.name + ":" + dep.version + "\",\n";
    }
    rootLuaurc += "    }\n}\n";
    return rootLuaurc;
}

std::optional<Subtree> Subtree::create(Info info)
{
    std::string_view entryFile = info.entryFile;
    if (entryFile.find(info.rootDirectory) != 0)
        return std::nullopt;

    if (entryFile.size() <= info.rootDirectory.size())
        return std::nullopt;

    if (entryFile[info.rootDirectory.size()] != '/' && entryFile[info.rootDirectory.size()] != '\\')
        return std::nullopt;

    std::string entryFileWithoutRoot = info.entryFile.substr(info.rootDirectory.size() + 1);

    std::optional<ModulePath> currentModulePath = ModulePath::create(info.rootDirectory, entryFileWithoutRoot, isFile, isDirectory);
    if (!currentModulePath)
        return std::nullopt;

    return Subtree{std::move(*currentModulePath), generateRootLuaurc(info.dependencies)};
}

Subtree::Subtree(ModulePath currentModulePath, std::string generatedRootLuaurc)
    : currentModulePath(std::move(currentModulePath))
    , generatedRootLuaurc(std::move(generatedRootLuaurc))
{
}

NavigationStatus Subtree::toParent()
{
    NavigationStatus status = currentModulePath.toParent();
    if (status == NavigationStatus::NotFound)
    {
        if (atGeneratedRoot)
            return NavigationStatus::NotFound;

        atGeneratedRoot = true;
        return NavigationStatus::Success;
    }

    return status;
}

NavigationStatus Subtree::toChild(const std::string& name)
{
    atGeneratedRoot = false;
    return currentModulePath.toChild(name);
}

bool Subtree::isConfigPresent() const
{
    if (atGeneratedRoot)
        return true;

    return isFile(currentModulePath.getPotentialLuaurcPath());
}

std::optional<std::string> Subtree::getConfig() const
{
    if (atGeneratedRoot)
        return generatedRootLuaurc;

    return readFile(currentModulePath.getPotentialLuaurcPath());
}

bool Subtree::isModulePresent() const
{
    if (atGeneratedRoot)
        return false;

    ResolvedRealPath result = currentModulePath.getRealPath();
    if (result.status != NavigationStatus::Success)
        return false;

    return isFile(result.realPath);
}

std::string Subtree::getCurrentPath() const
{
    ResolvedRealPath result = currentModulePath.getRealPath();
    if (result.status != NavigationStatus::Success)
        return "";

    return result.realPath;
}

Vfs Vfs::create(std::vector<Identifier> directDependencies, std::vector<std::pair<Identifier, Info>> libraries)
{
    std::map<Identifier, Info> librariesMap;
    for (auto& [identifier, info] : libraries)
    {
        librariesMap[std::move(identifier)] = std::move(info);
    }

    return Vfs{std::move(librariesMap), generateRootLuaurc(directDependencies)};
}

Vfs::Vfs(std::map<Identifier, Info> libraries, std::string generatedRootLuaurc)
    : libraries(std::move(libraries))
    , generatedRootLuaurc(std::move(generatedRootLuaurc))
{
}

NavigationStatus Vfs::resetToPath(const std::string& path)
{
    for (const auto& [identifier, info] : libraries)
    {
        if (path.find(info.rootDirectory) == 0)
        {
            return jumpToLibrary(identifier);
        }
    }

    currentSubtree = std::nullopt;
    vfsType = VFSType::Disk;
    atDiskFakeRoot = false;

    return fileVfs.resetToPath(path);
}

NavigationStatus Vfs::jumpToLibrary(const std::string& identifierStringified)
{
    if (identifierStringified.empty() || identifierStringified[0] != '$')
        return NavigationStatus::NotFound;

    Identifier identifier;
    size_t colonPos = identifierStringified.find(':');
    if (colonPos == std::string::npos)
        return NavigationStatus::NotFound;

    identifier.name = identifierStringified.substr(1, colonPos - 1);
    identifier.version = identifierStringified.substr(colonPos + 1);

    return jumpToLibrary(identifier);
}

NavigationStatus Vfs::jumpToLibrary(Identifier identifier)
{
    if (libraries.find(identifier) == libraries.end())
        return NavigationStatus::NotFound;

    std::optional<Subtree> st = Subtree::create(libraries.at(identifier));
    if (!st)
        return NavigationStatus::NotFound;

    currentSubtree = std::move(*st);
    vfsType = VFSType::Library;
    atDiskFakeRoot = false;

    return NavigationStatus::Success;
}

NavigationStatus Vfs::toParent()
{
    NavigationStatus status;

    switch (vfsType)
    {
    case VFSType::Disk:
        status = fileVfs.toParent();
        break;
    case VFSType::Library:
        LUAU_ASSERT(currentSubtree);
        status = currentSubtree->toParent();
        break;
    default:
        status = NavigationStatus::NotFound;
        break;
    }

    if (status == NavigationStatus::NotFound)
    {
        if (atDiskFakeRoot)
            return NavigationStatus::NotFound;

        atDiskFakeRoot = true;
        return NavigationStatus::Success;
    }

    return status;
}

NavigationStatus Vfs::toChild(const std::string& name)
{
    atDiskFakeRoot = false;

    switch (vfsType)
    {
    case VFSType::Disk:
        return fileVfs.toChild(name);
    case VFSType::Library:
        LUAU_ASSERT(currentSubtree);
        return currentSubtree->toChild(name);
    default:
        return NavigationStatus::NotFound;
    }
}

bool Vfs::isConfigPresent() const
{
    if (atDiskFakeRoot)
        return true;

    switch (vfsType)
    {
    case VFSType::Disk:
        return fileVfs.isConfigPresent();
    case VFSType::Library:
        LUAU_ASSERT(currentSubtree);
        return currentSubtree->isConfigPresent();
    default:
        return false;
    }
}

std::optional<std::string> Vfs::getConfig() const
{
    if (atDiskFakeRoot)
        return generatedRootLuaurc;

    switch (vfsType)
    {
    case VFSType::Disk:
        return fileVfs.getConfig();
    case VFSType::Library:
        LUAU_ASSERT(currentSubtree);
        return currentSubtree->getConfig();
    default:
        return std::nullopt;
    }
}

bool Vfs::isModulePresent() const
{
    if (atDiskFakeRoot)
        return false;

    switch (vfsType)
    {
    case VFSType::Disk:
        return fileVfs.isModulePresent();
    case VFSType::Library:
        LUAU_ASSERT(currentSubtree);
        return currentSubtree->isModulePresent();
    default:
        return false;
    }
}

std::optional<std::string> Vfs::getContents(const std::string& path) const
{
    return readFile(path);
}

std::string Vfs::getCurrentPath() const
{
    switch (vfsType)
    {
    case VFSType::Disk:
        return fileVfs.getAbsoluteFilePath();
    case VFSType::Library:
        LUAU_ASSERT(currentSubtree);
        return currentSubtree->getCurrentPath();
    default:
        return "";
    }
}

} // namespace Library
