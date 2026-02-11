#include "lute/userlandvfs.h"

#include "lute/common.h"
#include "lute/modulepath.h"

#include "Luau/Common.h"
#include "Luau/Config.h"
#include "Luau/FileUtils.h"
#include "Luau/LuauConfig.h"

#include <optional>
#include <string>

namespace Package
{

std::optional<Subtree> Subtree::create(Info info)
{
    std::string_view entryFile = info.entryFile;
    if (entryFile.rfind(info.rootDirectory, 0) != 0)
        return std::nullopt;

    if (entryFile.size() <= info.rootDirectory.size())
        return std::nullopt;

    if (entryFile[info.rootDirectory.size()] != '/' && entryFile[info.rootDirectory.size()] != '\\')
        return std::nullopt;

    std::string entryFileWithoutRoot = info.entryFile.substr(info.rootDirectory.size() + 1);

    std::optional<ModulePath> currentModulePath = ModulePath::create(info.rootDirectory, entryFileWithoutRoot, isFile, isDirectory);
    if (!currentModulePath)
        return std::nullopt;

    return Subtree{std::move(*currentModulePath), std::move(info)};
}

Subtree::Subtree(ModulePath currentModulePath, Info info)
    : currentModulePath(std::move(currentModulePath))
    , info(std::move(info))
{
}

NavigationStatus Subtree::toParent()
{
    return currentModulePath.toParent();
}

NavigationStatus Subtree::toChild(const std::string& name)
{
    return currentModulePath.toChild(name);
}

ConfigStatus Subtree::getConfigStatus() const
{
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
    ConfigStatus status = getConfigStatus();
    LUTE_ASSERT(status == ConfigStatus::PresentJson || status == ConfigStatus::PresentLuau);

    if (status == ConfigStatus::PresentJson)
        return readFile(currentModulePath.getPotentialConfigPath(Luau::kConfigName));
    else if (status == ConfigStatus::PresentLuau)
        return readFile(currentModulePath.getPotentialConfigPath(Luau::kLuauConfigName));

    LUTE_UNREACHABLE();
}

bool Subtree::isModulePresent() const
{
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

Info Subtree::getInfo() const
{
    return info;
}

UserlandVfs UserlandVfs::create(std::vector<Identifier> directDependencies, std::vector<std::pair<Identifier, Info>> allDependencies)
{
    DependencyMap allDependenciesMap{{}};
    for (auto& [identifier, info] : allDependencies)
    {
        allDependenciesMap[std::move(identifier)] = std::move(info);
    }

    return UserlandVfs{std::move(directDependencies), std::move(allDependenciesMap)};
}

UserlandVfs::UserlandVfs(std::vector<Identifier> directDependencies, DependencyMap allDependencies)
    : directDependencies(std::move(directDependencies))
    , allDependencies(std::move(allDependencies))
{
}

NavigationStatus UserlandVfs::resetToPath(const std::string& path)
{
    for (const auto& [identifier, info] : allDependencies)
    {
        if (path.rfind(info.rootDirectory, 0) == 0)
            return jumpToDependencySubtree(identifier);
    }

    currentSubtree = std::nullopt;
    vfsType = VFSType::Disk;

    return fileVfs.resetToPath(path);
}

NavigationStatus UserlandVfs::toAliasFallback(std::string_view aliasUnprefixed)
{
    std::vector<Identifier> availableDependencies;
    switch (vfsType)
    {
    case VFSType::Disk:
        availableDependencies = directDependencies;
        break;
    case VFSType::Subtree:
        LUTE_ASSERT(currentSubtree);
        availableDependencies = currentSubtree->getInfo().dependencies;
    }

    for (const Identifier& identifier : availableDependencies)
    {
        if (identifier.name == aliasUnprefixed)
            return jumpToDependencySubtree(identifier);
    }

    return NavigationStatus::NotFound;
}

NavigationStatus UserlandVfs::jumpToDependencySubtree(const Identifier& dependency)
{
    Info* info = allDependencies.find(dependency);
    if (!info)
        return NavigationStatus::NotFound;

    std::optional<Subtree> st = Subtree::create(*info);
    if (!st)
        return NavigationStatus::NotFound;

    currentSubtree = std::move(*st);
    vfsType = VFSType::Subtree;

    return NavigationStatus::Success;
}

NavigationStatus UserlandVfs::toParent()
{
    NavigationStatus status = NavigationStatus::NotFound;
    switch (vfsType)
    {
    case VFSType::Disk:
        status = fileVfs.toParent();
        break;
    case VFSType::Subtree:
        LUTE_ASSERT(currentSubtree);
        status = currentSubtree->toParent();
        break;
    }

    return status;
}

NavigationStatus UserlandVfs::toChild(const std::string& name)
{
    NavigationStatus status = NavigationStatus::NotFound;
    switch (vfsType)
    {
    case VFSType::Disk:
        status = fileVfs.toChild(name);
        break;
    case VFSType::Subtree:
        LUTE_ASSERT(currentSubtree);
        status = currentSubtree->toChild(name);
        break;
    }
    return status;
}

ConfigStatus UserlandVfs::getConfigStatus() const
{
    ConfigStatus status = ConfigStatus::Ambiguous;
    switch (vfsType)
    {
    case VFSType::Disk:
        status = fileVfs.getConfigStatus();
        break;
    case VFSType::Subtree:
        LUTE_ASSERT(currentSubtree);
        status = currentSubtree->getConfigStatus();
        break;
    }
    return status;
}

std::optional<std::string> UserlandVfs::getConfig() const
{
    std::optional<std::string> config;
    switch (vfsType)
    {
    case VFSType::Disk:
        config = fileVfs.getConfig();
        break;
    case VFSType::Subtree:
        LUTE_ASSERT(currentSubtree);
        config = currentSubtree->getConfig();
        break;
    }
    return config;
}

bool UserlandVfs::isModulePresent() const
{
    bool isPresent = false;
    switch (vfsType)
    {
    case VFSType::Disk:
        isPresent = fileVfs.isModulePresent();
        break;
    case VFSType::Subtree:
        LUTE_ASSERT(currentSubtree);
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
        LUTE_ASSERT(currentSubtree);
        path = currentSubtree->getCurrentPath();
        break;
    }
    return path;
}

} // namespace Package
