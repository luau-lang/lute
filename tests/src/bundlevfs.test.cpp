#include "lute/bundlevfs.h"

#include "lute/modulepath.h"

#include "Luau/DenseHash.h"

#include "doctest.h"

namespace
{

BundleVfs makeBundle()
{
    Luau::DenseHashMap<std::string, std::string> bundleMap{""};
    bundleMap["modules/main.luau"] = "bytecode-main";
    bundleMap[".loom/store/package@v0.2.0/modules/init.luau"] = "bytecode-init";
    bundleMap[".loom/store/package@v0.2.0/modules/locate.luau"] = "bytecode-locate";

    Luau::DenseHashMap<std::string, std::string> configs{""};
    return BundleVfs{std::move(configs), std::move(bundleMap)};
}

} // namespace

TEST_CASE("BundleVfs_resets_to_root")
{
    BundleVfs vfs = makeBundle();
    CHECK(vfs.resetToPath("@bundle") == NavigationStatus::Success);
}

TEST_CASE("BundleVfs_resets_to_existing_bundle_directory")
{
    BundleVfs vfs = makeBundle();
    CHECK(vfs.resetToPath("@bundle/.loom/store/package@v0.2.0/modules") == NavigationStatus::Success);
}

TEST_CASE("BundleVfs_returns_not_found_for_unknown_bundle_path")
{
    BundleVfs vfs = makeBundle();
    CHECK(vfs.resetToPath("@bundle/missing/path") == NavigationStatus::NotFound);
}

TEST_CASE("BundleVfs_bridges_tilde_alias_to_bundle_path")
{
    // Simulates the loom case: alias value is "~/.loom/store/package@v0.2.0/modules"
    // and the bundle has the matching directory at LCR-stripped path.
    BundleVfs vfs = makeBundle();
    CHECK(vfs.resetToPath("~/.loom/store/package@v0.2.0/modules") == NavigationStatus::Success);

    // Directories with init.luau auto-resolve to the init module — confirms the
    // bridge points at a real bundled file, not an empty directory.
    CHECK(vfs.isModulePresent());
}

TEST_CASE("BundleVfs_user_tilde_path_returns_not_found")
{
    // ~user/foo is not supported: BundleVfs has no notion of other users' homes.
    BundleVfs vfs = makeBundle();
    CHECK(vfs.resetToPath("~someone/anything") == NavigationStatus::NotFound);
}

TEST_CASE("BundleVfs_absolute_disk_path_returns_not_found")
{
    // Absolute paths without a tilde aren't bridged; they would require knowing the LCR.
    BundleVfs vfs = makeBundle();
    CHECK(vfs.resetToPath("/Users/anyone/.loom/store/package@v0.2.0/modules") == NavigationStatus::NotFound);
}
