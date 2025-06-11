#include "lute/libraryvfs.h"

#include "lute/modulepath.h"

#include "Luau/FileUtils.h"

#include <optional>
#include <string>

namespace Library
{

std::optional<Vfs> Vfs::create(Info entryPoint, std::vector<std::pair<Identifier, Info>> libraries)
{
    std::optional<Subtree> currentSubtree = Subtree::create(entryPoint);
    if (!currentSubtree)
        return std::nullopt;

    std::map<Identifier, Info> librariesMap;
    for (auto& [identifier, info] : libraries)
    {
        librariesMap[std::move(identifier)] = std::move(info);
    }

    return Vfs{std::move(entryPoint), std::move(*currentSubtree), std::move(librariesMap)};
}

Vfs::Vfs(Info entryPoint, Subtree currentSubtree, std::map<Identifier, Info> libraries)
    : entryInfo(std::move(entryPoint))
    , currentSubtree(std::move(currentSubtree))
    , libraries(std::move(libraries))
{
}

NavigationStatus Vfs::jumpToLibrary(Identifier identifier)
{
    if (libraries.find(identifier) == libraries.end())
        return NavigationStatus::NotFound;

    std::optional<Subtree> st = Subtree::create(libraries[identifier]);
    if (!st)
        return NavigationStatus::NotFound;

    currentSubtree = std::move(*st);
    return NavigationStatus::Success;
}

NavigationStatus Vfs::toParent()
{
    return currentSubtree.toParent();
}

NavigationStatus Vfs::toChild(const std::string& name)
{
    return currentSubtree.toChild(name);
}

bool Vfs::isConfigPresent() const
{
    return currentSubtree.isConfigPresent();
}

std::optional<std::string> Vfs::getConfig() const
{
    return currentSubtree.getConfig();
}

bool Vfs::isModulePresent() const
{
    return currentSubtree.isModulePresent();
}

std::optional<std::string> Vfs::getContents() const
{
    return currentSubtree.getContents();
}

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

    if (entryFile.size() <= info.rootDirectory.size() || entryFile[info.rootDirectory.size()] != '/' || entryFile[info.rootDirectory.size()] != '\\')
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

std::optional<std::string> Subtree::getContents() const
{
    ResolvedRealPath result = currentModulePath.getRealPath();
    if (result.status != NavigationStatus::Success)
        return std::nullopt;

    return readFile(result.realPath);
}

} // namespace Library
