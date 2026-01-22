#include "lute/staticrequires.h"

#include "Luau/FileUtils.h"

#include <algorithm>
#include <string>
#include <vector>

#include "doctest.h"
#include "lutefixture.h"
#include "luteprojectroot.h"

TEST_CASE_FIXTURE(LuteFixture, "staticrequiretracer_simple_dependencies")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");
    std::string entryPoint = joinPaths(testDir, "main.luau");

    StaticRequireTracer tracer{getReporter()};
    tracer.trace(entryPoint);

    auto pairs = tracer.getStaticRequirePairs();

    // Should find: main.luau, utils.luau, lib/helper.luau, shared.luau, dep/option.luau, other/module.luau, other/lib/example.luau
    REQUIRE(pairs.size() == 7);

    // Entry point should be first
    CHECK(pairs[0].first == "main.luau");

    std::vector<std::string> expectedFiles = {
        "main.luau", "utils.luau", "lib/helper.luau", "shared.luau", "dep/option.luau", "other/lib/example.luau", "other/module.luau"
    };

    for (const auto& expected : expectedFiles)
    {
        std::string absolutePath = joinPaths(tracer.getLowestCommonRoot(), expected);
        CHECK(tracer.containsAbsolute(absolutePath));
    }

    // Verify .luaurc file was discovered
    auto luaurcFiles = tracer.getLuaurcFiles();
    REQUIRE(luaurcFiles.size() == 2);

    // Check that .luaurc exists in the map
    CHECK(luaurcFiles.find(".luaurc") != nullptr);
    CHECK(luaurcFiles.find("other/.luaurc") != nullptr);
}

TEST_CASE_FIXTURE(LuteFixture, "staticrequiretracer_circular_dependencies")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");
    std::string entryPoint = joinPaths(testDir, "circular_a.luau");

    StaticRequireTracer tracer{getReporter()};
    tracer.trace(entryPoint);

    auto pairs = tracer.getStaticRequirePairs();

    // Should find both circular_a and circular_b without infinite loop
    REQUIRE(pairs.size() == 2);

    // Entry point should be first
    CHECK(pairs[0].first == "circular_a.luau");

    // Both files should be in the list using absolute paths
    std::string absoluteA = joinPaths(tracer.getLowestCommonRoot(), "circular_a.luau");
    std::string absoluteB = joinPaths(tracer.getLowestCommonRoot(), "circular_b.luau");

    CHECK(tracer.containsAbsolute(absoluteA));
    CHECK(tracer.containsAbsolute(absoluteB));

    // Verify .luaurc file was discovered
    auto luaurcFiles = tracer.getLuaurcFiles();
    REQUIRE(luaurcFiles.size() == 1);
    CHECK(luaurcFiles.find(".luaurc") != nullptr);
}

TEST_CASE_FIXTURE(LuteFixture, "staticrequiretracer_no_dependencies")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");
    std::string entryPoint = joinPaths(testDir, "utils.luau");

    StaticRequireTracer tracer{getReporter()};
    tracer.trace(entryPoint);

    auto pairs = tracer.getStaticRequirePairs();

    // utils.luau has no requires, should only return itself
    REQUIRE(pairs.size() == 1);
    CHECK(pairs[0].first == "utils.luau");

    // Verify .luaurc file was discovered (should find it in the same directory)
    auto luaurcFiles = tracer.getLuaurcFiles();
    REQUIRE(luaurcFiles.size() == 1);
    CHECK(luaurcFiles.find(".luaurc") != nullptr);
}

TEST_CASE_FIXTURE(LuteFixture, "staticrequiretracer_relative_paths")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");
    std::string entryPoint = joinPaths(testDir, "lib/helper.luau");

    StaticRequireTracer tracer{getReporter()};
    tracer.trace(entryPoint);

    auto pairs = tracer.getStaticRequirePairs();

    // helper.luau requires ../shared, should resolve correctly
    REQUIRE(pairs.size() == 2);

    CHECK(pairs[0].first == "lib/helper.luau");

    std::string absoluteShared = joinPaths(tracer.getLowestCommonRoot(), "shared.luau");
    CHECK(tracer.containsAbsolute(absoluteShared));

    // Verify .luaurc file was discovered (should find it in parent directory)
    auto luaurcFiles = tracer.getLuaurcFiles();
    REQUIRE(luaurcFiles.size() == 1);
    CHECK(luaurcFiles.find(".luaurc") != nullptr);
}

TEST_CASE_FIXTURE(LuteFixture, "staticrequiretracer_requirealias")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");
    std::string entryPoint = joinPaths(testDir, "dep/requirealias.luau");

    StaticRequireTracer tracer{getReporter()};
    tracer.trace(entryPoint);

    auto pairs = tracer.getStaticRequirePairs();

    // requirealias.luau requires @otherlib/example.luau, should resolve correctly
    REQUIRE(pairs.size() == 2);

    CHECK(pairs[0].first == "dep/requirealias.luau");

    std::string absoluteExample = joinPaths(tracer.getLowestCommonRoot(), "dep/nested/example.luau");
    CHECK(tracer.containsAbsolute(absoluteExample));

    // Verify that the lowestCommonRoot is staticrequires, NOT dep even though entry point and dependency are in dep
    CHECK(tracer.getLowestCommonRoot() == testDir);

    // Verify .luaurc file was discovered (should find it in parent directory)
    auto luaurcFiles = tracer.getLuaurcFiles();
    REQUIRE(luaurcFiles.size() == 1);
    CHECK(luaurcFiles.find(".luaurc") != nullptr);
}

TEST_CASE_FIXTURE(LuteFixture, "staticrequiretracer_require_graph")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");
    StaticRequireTracer tracer{getReporter()};
    std::string entryPoint = joinPaths(testDir, "main.luau");

    tracer.trace(entryPoint);

    // Build absolute paths
    std::string mainPath = joinPaths(testDir, "main.luau");
    std::string utilsPath = joinPaths(testDir, "utils.luau");
    std::string helperPath = joinPaths(testDir, "lib/helper.luau");
    std::string sharedPath = joinPaths(testDir, "shared.luau");
    std::string otherExample = joinPaths(testDir, "other/lib/example.luau");
    std::string otherModule = joinPaths(testDir, "other/module.luau");
    std::string dep = joinPaths(testDir, "dep/option.luau");

    // Verify all expected files were discovered
    CHECK(tracer.containsAbsolute(mainPath));
    CHECK(tracer.containsAbsolute(utilsPath));
    CHECK(tracer.containsAbsolute(helperPath));
    CHECK(tracer.containsAbsolute(sharedPath));
    CHECK(tracer.containsAbsolute(otherExample));
    CHECK(tracer.containsAbsolute(otherModule));
    CHECK(tracer.containsAbsolute(dep));


    // Verify .luaurc file was discovered
    auto luaurcFiles = tracer.getLuaurcFiles();
    REQUIRE(luaurcFiles.size() == 2);
    CHECK(luaurcFiles.find(".luaurc") != nullptr);
    CHECK(luaurcFiles.find("other/.luaurc") != nullptr);

    // Verify the graph can be printed without errors (visual inspection of output)
    tracer.printRequireGraph();
}

TEST_CASE("staticrequiretracer_find_lowest_common_root")
{
    SUBCASE("single_file")
    {
        std::vector<std::string> paths = {"/home/user/project/src/main.luau"};
        std::string root = StaticRequireTracer::findLowestCommonRoot(paths);
        CHECK(root == "/home/user/project/src");
    }

    SUBCASE("same_directory")
    {
        std::vector<std::string> paths = {
            "/home/user/project/src/main.luau", "/home/user/project/src/utils.luau", "/home/user/project/src/helper.luau"
        };
        std::string root = StaticRequireTracer::findLowestCommonRoot(paths);
        CHECK(root == "/home/user/project/src");
    }

    SUBCASE("nested_directories")
    {
        std::vector<std::string> paths = {
            "/home/user/project/src/main.luau", "/home/user/project/src/utils.luau", "/home/user/project/src/lib/helper.luau"
        };
        std::string root = StaticRequireTracer::findLowestCommonRoot(paths);
        CHECK(root == "/home/user/project/src");
    }

    SUBCASE("different_subdirectories")
    {
        std::vector<std::string> paths = {"/home/user/project/tests/src/main.luau", "/home/user/project/tests/lib/helper.luau"};
        std::string root = StaticRequireTracer::findLowestCommonRoot(paths);
        CHECK(root == "/home/user/project/tests");
    }

    SUBCASE("no_common_root")
    {
        std::vector<std::string> paths = {"/home/user/project1/main.luau", "/var/lib/project2/utils.luau"};
        std::string root = StaticRequireTracer::findLowestCommonRoot(paths);
        // Should find at least the root directory "/"
        CHECK(!root.empty());
    }

    SUBCASE("empty_vector")
    {
        std::vector<std::string> paths = {};
        std::string root = StaticRequireTracer::findLowestCommonRoot(paths);
        CHECK(root.empty());
    }
}

TEST_CASE_FIXTURE(LuteFixture, "staticrequiretracer_bundle_paths_and_contains")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");
    std::string entryPoint = joinPaths(testDir, "main.luau");

    StaticRequireTracer tracer{getReporter()};
    tracer.trace(entryPoint);

    // Get the lowest common root
    std::string commonRoot = tracer.getLowestCommonRoot();
    CHECK(commonRoot == testDir);

    // Get discovered files as pairs
    auto pairs = tracer.getStaticRequirePairs();
    REQUIRE(pairs.size() == 7);

    // Verify bundle paths (without common prefix)
    std::vector<std::string> expectedBundlePaths = {
        "main.luau", "utils.luau", "lib/helper.luau", "shared.luau", "dep/option.luau", "other/lib/example.luau", "other/module.luau"
    };

    for (const auto& expected : expectedBundlePaths)
    {
        bool found = false;
        for (const auto& [bundlePath, absolutePath] : pairs)
        {
            if (bundlePath == expected)
            {
                found = true;
                break;
            }
        }
        CHECK(found);
    }

    // Test containsAbsolute() method with absolute paths
    std::string mainAbsolute = joinPaths(commonRoot, "main.luau");
    CHECK(tracer.containsAbsolute(mainAbsolute));

    std::string helperAbsolute = joinPaths(commonRoot, "lib/helper.luau");
    CHECK(tracer.containsAbsolute(helperAbsolute));

    // Test non-existent module
    std::string nonExistentAbsolute = joinPaths(commonRoot, "nonexistent.luau");
    CHECK(!tracer.containsAbsolute(nonExistentAbsolute));

    // Verify .luaurc file was discovered
    auto luaurcFiles = tracer.getLuaurcFiles();
    REQUIRE(luaurcFiles.size() == 2);
    CHECK(luaurcFiles.find(".luaurc") != nullptr);
    CHECK(luaurcFiles.find("other/.luaurc") != nullptr);
}

TEST_CASE_FIXTURE(LuteFixture, "staticrequiretracer_multiple_luaurc_files")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");
    std::string entryPoint = joinPaths(testDir, "main.luau");

    StaticRequireTracer tracer{getReporter()};
    tracer.trace(entryPoint);

    // Get discovered files as pairs
    auto pairs = tracer.getStaticRequirePairs();
    REQUIRE(pairs.size() == 7); // main, utils, lib/helper, shared, other/module, other/lib/example, dep/option

    // Verify all expected files are discovered including those in the other/ directory
    std::vector<std::string> expectedBundlePaths = {
        "main.luau", "utils.luau", "lib/helper.luau", "shared.luau", "other/module.luau", "other/lib/example.luau"
    };

    for (const auto& expected : expectedBundlePaths)
    {
        bool found = false;
        for (const auto& [bundlePath, absolutePath] : pairs)
        {
            if (bundlePath == expected)
            {
                found = true;
                break;
            }
        }
        CHECK(found);
    }

    // Verify both .luaurc files were discovered
    auto luaurcFiles = tracer.getLuaurcFiles();
    REQUIRE(luaurcFiles.size() == 2);

    // Check that both .luaurc files exist in the map
    const std::string* rootLuaurc = luaurcFiles.find(".luaurc");
    REQUIRE(rootLuaurc != nullptr);

    const std::string* otherLuaurc = luaurcFiles.find("other/.luaurc");
    REQUIRE(otherLuaurc != nullptr);
}
