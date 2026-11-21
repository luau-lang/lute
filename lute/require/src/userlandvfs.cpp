#include "lute/userlandvfs.h"

#include "lute/common.h"
#include "lute/fileutils.h"
#include "lute/modulepath.h"

#include "Luau/Common.h"
#include "Luau/Config.h"
#include "Luau/FileUtils.h"
#include "Luau/LuauConfig.h"

#include <optional>
#include <string>
#include <string_view>

namespace Package
{

std::optional<Subtree> Subtree::create(Info info, const std::string& pathInRoot)
{
    std::optional<ModulePath> currentModulePath = ModulePath::create(info.rootDirectory, pathInRoot, Lute::isFile, Lute::isDirectory);
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
    bool luaurcExists = Lute::isFile(currentModulePath.getPotentialConfigPath(Luau::kConfigName));
    bool luauConfigExists = Lute::isFile(currentModulePath.getPotentialConfigPath(Luau::kLuauConfigName));

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

    return Lute::isFile(result.realPath);
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

// Returns true if path is rootDirectory itself or lies inside it. 
static bool isWithinRoot(std::string_view path, std::string_view rootDirectory)
{
    if (rootDirectory.empty() || path.rfind(rootDirectory, 0) != 0)
        return false;

    if (path.size() == rootDirectory.size())
        return true;

    char last = rootDirectory.back();
    if (last == '/' || last == '\\')
        return true;

    char next = path[rootDirectory.size()];
    return next == '/' || next == '\\';
}

// Install roots may overlap (e.g. a package vendored inside another package's
// root), so the most specific root containing the path owns it.
const Identifier* UserlandVfs::findOwningDependency(const std::string& path) const
{
    const Identifier* owner = nullptr;
    size_t ownerRootLength = 0;
    for (const auto& [identifier, info] : allDependencies)
    {
        if (info.rootDirectory.size() > ownerRootLength && isWithinRoot(path, info.rootDirectory))
        {
            owner = &identifier;
            ownerRootLength = info.rootDirectory.size();
        }
    }

    return owner;
}

NavigationStatus UserlandVfs::resetToPath(const std::string& path)
{
    if (const Identifier* owner = findOwningDependency(path))
        return jumpToDependencySubtree(*owner, path);

    currentSubtree = std::nullopt;
    vfsType = VFSType::Disk;

    return fileVfs.resetToPath(path);
}

NavigationStatus UserlandVfs::jumpToAlias(const std::string& path)
{
    if (const Identifier* owner = findOwningDependency(path))
        return jumpToDependencySubtree(*owner, path);

    currentSubtree = std::nullopt;
    vfsType = VFSType::Disk;

    return fileVfs.jumpToAlias(path);
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

NavigationStatus UserlandVfs::jumpToDependencySubtree(const Identifier& dependency, std::optional<std::string_view> absolutePath)
{
    Info* info = allDependencies.find(dependency);
    if (!info)
        return NavigationStatus::NotFound;

    std::string pathInRoot;
    if (absolutePath)
    {
        std::string_view relative = absolutePath->substr(info->rootDirectory.size());
        if (!relative.empty() && (relative.front() == '/' || relative.front() == '\\'))
            relative.remove_prefix(1);
        pathInRoot = relative;
    }

    std::optional<Subtree> st = Subtree::create(*info, pathInRoot);
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
