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

private:
    Subtree(ModulePath currentModulePath, std::string generatedRootLuaurc);

    ModulePath currentModulePath;
    std::string generatedRootLuaurc;
    bool atGeneratedRoot = false;
};

class UserlandVfs
{
public:
    static UserlandVfs create(std::vector<Identifier> directDependencies, std::vector<std::pair<Identifier, Info>> allDependencies);

    NavigationStatus resetToPath(const std::string& path);
    NavigationStatus jumpToDependencySubtree(const std::string& identifierStringified);

    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

    ConfigStatus getConfigStatus() const;
    std::optional<std::string> getConfig() const;

    bool isModulePresent() const;
    std::optional<std::string> getContents(const std::string& path) const;

    std::string getCurrentPath() const;

private:
    UserlandVfs(std::map<Identifier, Info> allDependencies, std::string generatedRootLuaurc);
    NavigationStatus jumpToDependencySubtreeImpl(Identifier identifier);

    enum class VFSType
    {
        Disk,
        Subtree,
    };

    VFSType vfsType = VFSType::Disk;

    FileVfs fileVfs;
    std::optional<Subtree> currentSubtree = std::nullopt;
    std::map<Identifier, Info> allDependencies;

    bool atDiskFakeRoot = false;
    std::string generatedRootLuaurc;
};

} // namespace Package
