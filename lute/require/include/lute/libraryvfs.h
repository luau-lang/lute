#pragma once

#include "modulepath.h"

#include <map>
#include <optional>
#include <string>
#include <utility>
namespace Library
{

struct Identifier
{
    std::string name;
    std::string version;

    bool operator<(const Identifier& other) const
    {
        return std::tie(name, version) < std::tie(other.name, other.version);
    }
};

struct Info
{
    std::string rootDirectory;
    std::string entryFile;
    std::vector<Identifier> dependencies;
};

class Subtree
{
public:
    static std::optional<Subtree> create(Info info);

    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

    bool isConfigPresent() const;
    std::optional<std::string> getConfig() const;

    bool isModulePresent() const;
    std::optional<std::string> getContents() const;

private:
    Subtree(ModulePath currentModulePath, std::string generatedRootLuaurc);

    ModulePath currentModulePath;
    std::string generatedRootLuaurc;
    bool atGeneratedRoot = false;
};

class Vfs
{
public:
    static std::optional<Vfs> create(Info entryPoint, std::vector<std::pair<Identifier, Info>> libraries);

    NavigationStatus jumpToLibrary(Identifier identifier);
    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

    bool isConfigPresent() const;
    std::optional<std::string> getConfig() const;

    bool isModulePresent() const;
    std::optional<std::string> getContents() const;

private:
    Vfs(Info entryPoint, Subtree currentSubtree, std::map<Identifier, Info> libraries);

    Info entryInfo;
    Subtree currentSubtree;
    std::map<Identifier, Info> libraries;
};

} // namespace Library
