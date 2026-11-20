#pragma once

#include "lute/filevfs.h"
#include "lute/modulepath.h"

#include "Luau/DenseHash.h"
#include "Luau/StringUtils.h"

#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace Package
{

struct Identifier
{
    std::string name;
    std::string version;
    std::string lockfileKey;

    bool operator==(const Identifier& other) const
    {
        return std::tie(name, version, lockfileKey) == std::tie(other.name, other.version, other.lockfileKey);
    }
    bool operator!=(const Identifier& other) const
    {
        return !(*this == other);
    }
};

struct IdentifierHashDefault
{
    size_t operator()(const Identifier& id) const
    {
        return Luau::detail::DenseHashDefault<std::string>()(
            Luau::format("%s:%s:%s", id.name.c_str(), id.version.c_str(), id.lockfileKey.c_str())
        );
    }
};

struct Info
{
    std::string rootDirectory;
    std::vector<Identifier> dependencies;
};

class Subtree
{
public:
    static std::optional<Subtree> create(Info info, const std::string& pathInRoot);

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
    NavigationStatus jumpToAlias(const std::string& path);
    NavigationStatus toAliasFallback(std::string_view aliasUnprefixed);

    NavigationStatus toParent();
    NavigationStatus toChild(const std::string& name);

    ConfigStatus getConfigStatus() const;
    std::optional<std::string> getConfig() const;

    bool isModulePresent() const;
    std::optional<std::string> getContents(const std::string& path) const;

    std::string getCurrentPath() const;

private:
    using DependencyMap = Luau::DenseHashMap<Identifier, Info, IdentifierHashDefault>;

    UserlandVfs(std::vector<Identifier> directDependencies, DependencyMap allDependencies);

    const Identifier* findOwningDependency(const std::string& path) const;
    NavigationStatus jumpToDependencySubtree(const Identifier& dependency, std::optional<std::string_view> absolutePath = std::nullopt);

    enum class VFSType
    {
        Disk,
        Subtree,
    };

    VFSType vfsType = VFSType::Disk;

    FileVfs fileVfs;
    std::optional<Subtree> currentSubtree = std::nullopt;

    std::vector<Identifier> directDependencies;
    DependencyMap allDependencies;
};

} // namespace Package
