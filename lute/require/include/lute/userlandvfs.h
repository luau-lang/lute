#pragma once

#include "lute/filevfs.h"
#include "lute/modulepath.h"

#include <map>
#include <optional>
#include <string>
#include <utility>
#include <vector>

namespace Package
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

    ConfigStatus getConfigStatus() const;
    std::optional<std::string> getConfig() const;

    bool isModulePresent() const;

    std::string getCurrentPath() const;
    Info getInfo() const;

private:
    Subtree(ModulePath currentModulePath, Info info);

    ModulePath currentModulePath;
    Info info;
};

class UserlandVfs
{
public:
    static UserlandVfs create(std::vector<Identifier> directDependencies, std::vector<std::pair<Identifier, Info>> allDependencies);

    NavigationStatus resetToPath(const std::string& path);
    NavigationStatus toAliasFallback(std::string_view aliasUnprefixed);

    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

    ConfigStatus getConfigStatus() const;
    std::optional<std::string> getConfig() const;

    bool isModulePresent() const;
    std::optional<std::string> getContents(const std::string& path) const;

    std::string getCurrentPath() const;

private:
    UserlandVfs(std::vector<Identifier> directDependencies, std::map<Identifier, Info> allDependencies);

    NavigationStatus jumpToDependencySubtree(const Identifier& dependency);

    enum class VFSType
    {
        Disk,
        Subtree,
    };

    VFSType vfsType = VFSType::Disk;

    FileVfs fileVfs;
    std::optional<Subtree> currentSubtree = std::nullopt;

    std::vector<Identifier> directDependencies;
    std::map<Identifier, Info> allDependencies;
};

} // namespace Package
