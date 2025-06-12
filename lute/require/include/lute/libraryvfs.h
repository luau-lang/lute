#pragma once

#include "lute/filevfs.h"
#include "lute/modulepath.h"

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

    NavigationStatus resetToPath(const std::string& path);
    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

    bool isConfigPresent() const;
    std::optional<std::string> getConfig() const;

    bool isModulePresent() const;

    std::string getCurrentPath() const;

private:
    Subtree(ModulePath currentModulePath, std::string generatedRootLuaurc);

    ModulePath currentModulePath;
    std::string generatedRootLuaurc;
    bool atGeneratedRoot = false;
};

class Vfs
{
public:
    static Vfs create(std::vector<Identifier> directDependencies, std::vector<std::pair<Identifier, Info>> libraries);

    NavigationStatus resetToPath(const std::string& path);
    NavigationStatus jumpToLibrary(const std::string& identifierStringified);

    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

    bool isConfigPresent() const;
    std::optional<std::string> getConfig() const;

    bool isModulePresent() const;
    std::optional<std::string> getContents(const std::string& path) const;

    std::string getCurrentPath() const;

private:
    Vfs(std::map<Identifier, Info> libraries, std::string generatedRootLuaurc);
    NavigationStatus jumpToLibrary(Identifier identifier);

    enum class VFSType
    {
        Disk,
        Library,
    };

    VFSType vfsType = VFSType::Disk;

    FileVfs fileVfs;
    std::optional<Subtree> currentSubtree = std::nullopt;
    std::map<Identifier, Info> libraries;

    bool atDiskFakeRoot = false;
    std::string generatedRootLuaurc;
};

} // namespace Library
