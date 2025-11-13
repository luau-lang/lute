#include "lute/userlandvfs.h"

#include "lute/modulepath.h"

#include "Luau/Common.h"
#include "Luau/Config.h"
#include "Luau/FileUtils.h"
#include "Luau/LuauConfig.h"

#include <optional>
#include <string>

namespace Package
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

ConfigStatus Subtree::getConfigStatus() const
{
    if (atGeneratedRoot)
        return ConfigStatus::PresentJson;

    bool luaurcExists = isFile(currentModulePath.getPotentialConfigPath(Luau::kConfigName));
    bool luauConfigExists = isFile(currentModulePath.getPotentialConfigPath(Luau::kLuauConfigName));

    if (luaurcExists && luauConfigExists)
        return ConfigStatus::Ambiguous;
    else if (luauConfigExists)
        return ConfigStatus::PresentLuau;
    else if (luaurcExists)
        return ConfigStatus::PresentJson;

    return ConfigStatus::Absent;
}

std::optional<std::string> Subtree::getConfig() const
{
    if (atGeneratedRoot)
        return generatedRootLuaurc;

    ConfigStatus status = getConfigStatus();
    LUAU_ASSERT(status == ConfigStatus::PresentJson || status == ConfigStatus::PresentLuau);

    if (status == ConfigStatus::PresentJson)
        return readFile(currentModulePath.getPotentialConfigPath(Luau::kConfigName));
    else if (status == ConfigStatus::PresentLuau)
        return readFile(currentModulePath.getPotentialConfigPath(Luau::kLuauConfigName));

    LUAU_UNREACHABLE();
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

UserlandVfs UserlandVfs::create(std::vector<Identifier> directDependencies, std::vector<std::pair<Identifier, Info>> libraries)
{
    std::map<Identifier, Info> librariesMap;
    for (auto& [identifier, info] : libraries)
    {
        librariesMap[std::move(identifier)] = std::move(info);
    }

    return UserlandVfs{std::move(librariesMap), generateRootLuaurc(directDependencies)};
}

UserlandVfs::UserlandVfs(std::map<Identifier, Info> libraries, std::string generatedRootLuaurc)
    : libraries(std::move(libraries))
    , generatedRootLuaurc(std::move(generatedRootLuaurc))
{
}

NavigationStatus UserlandVfs::resetToPath(const std::string& path)
{
    for (const auto& [identifier, info] : libraries)
    {
        if (path.find(info.rootDirectory) == 0)
        {
            return jumpToDependencySubtreeImpl(identifier);
        }
    }

    currentSubtree = std::nullopt;
    vfsType = VFSType::Disk;
    atDiskFakeRoot = false;

    return fileVfs.resetToPath(path);
}

NavigationStatus UserlandVfs::jumpToDependencySubtree(const std::string& identifierStringified)
{
    if (identifierStringified.empty() || identifierStringified[0] != '$')
        return NavigationStatus::NotFound;

    Identifier identifier;
    size_t colonPos = identifierStringified.find(':');
    if (colonPos == std::string::npos)
        return NavigationStatus::NotFound;

    identifier.name = identifierStringified.substr(1, colonPos - 1);
    identifier.version = identifierStringified.substr(colonPos + 1);

    return jumpToDependencySubtreeImpl(identifier);
}

NavigationStatus UserlandVfs::jumpToDependencySubtreeImpl(Identifier identifier)
{
    if (libraries.find(identifier) == libraries.end())
        return NavigationStatus::NotFound;

    std::optional<Subtree> st = Subtree::create(libraries.at(identifier));
    if (!st)
        return NavigationStatus::NotFound;

    currentSubtree = std::move(*st);
    vfsType = VFSType::Subtree;
    atDiskFakeRoot = false;

    return NavigationStatus::Success;
}

NavigationStatus UserlandVfs::toParent()
{
    NavigationStatus status;

    switch (vfsType)
    {
    case VFSType::Disk:
        status = fileVfs.toParent();
        break;
    case VFSType::Subtree:
        LUAU_ASSERT(currentSubtree);
        status = currentSubtree->toParent();
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

NavigationStatus UserlandVfs::toChild(const std::string& name)
{
    atDiskFakeRoot = false;

    NavigationStatus status;
    switch (vfsType)
    {
    case VFSType::Disk:
        status = fileVfs.toChild(name);
        break;
    case VFSType::Subtree:
        LUAU_ASSERT(currentSubtree);
        status = currentSubtree->toChild(name);
        break;
    }
    return status;
}

ConfigStatus UserlandVfs::getConfigStatus() const
{
    if (atDiskFakeRoot)
        return ConfigStatus::PresentJson;

    ConfigStatus status = ConfigStatus::Ambiguous;
    switch (vfsType)
    {
    case VFSType::Disk:
        status = fileVfs.getConfigStatus();
        break;
    case VFSType::Subtree:
        LUAU_ASSERT(currentSubtree);
        status = currentSubtree->getConfigStatus();
        break;
    }
    return status;
}

std::optional<std::string> UserlandVfs::getConfig() const
{
    if (atDiskFakeRoot)
        return generatedRootLuaurc;

    std::optional<std::string> config;
    switch (vfsType)
    {
    case VFSType::Disk:
        config = fileVfs.getConfig();
        break;
    case VFSType::Subtree:
        LUAU_ASSERT(currentSubtree);
        config = currentSubtree->getConfig();
        break;
    }
    return config;
}

bool UserlandVfs::isModulePresent() const
{
    if (atDiskFakeRoot)
        return false;

    bool isPresent = false;
    switch (vfsType)
    {
    case VFSType::Disk:
        isPresent = fileVfs.isModulePresent();
        break;
    case VFSType::Subtree:
        LUAU_ASSERT(currentSubtree);
        isPresent = currentSubtree->isModulePresent();
        break;
    }
    return isPresent;
}

std::optional<std::string> UserlandVfs::getContents(const std::string& path) const
{
    return readFile(path);
}

std::string UserlandVfs::getCurrentPath() const
{
    std::string path;
    switch (vfsType)
    {
    case VFSType::Disk:
        path = fileVfs.getAbsoluteFilePath();
        break;
    case VFSType::Subtree:
        LUAU_ASSERT(currentSubtree);
        path = currentSubtree->getCurrentPath();
        break;
    }
    return path;
}

} // namespace Package
