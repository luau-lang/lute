#include "doctest.h"
#include "luteprojectroot.h"
#include "lute/staticrequires.h"

#include "Luau/FileUtils.h"

#include <algorithm>
#include <string>
#include <vector>

TEST_CASE("staticrequiretracer_simple_dependencies")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");

    StaticRequireTracer tracer;
    std::vector<std::string> deps = tracer.trace(testDir, "main.luau");

    // Should find: main.luau, utils.luau, lib/helper.luau, shared.luau
    REQUIRE(deps.size() == 4);

    // Entry point should be first
    CHECK(deps[0] == "main.luau");

    // Verify all expected files are present (paths are relative to testDir)
    std::vector<std::string> expectedFiles = {
        "main.luau",
        "utils.luau",
        "lib/helper.luau",
        "shared.luau"
    };

    for (const auto& expected : expectedFiles)
    {
        bool found = std::find(deps.begin(), deps.end(), expected) != deps.end();
        CHECK(found);
    }
}

TEST_CASE("staticrequiretracer_circular_dependencies")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");

    StaticRequireTracer tracer;
    std::vector<std::string> deps = tracer.trace(testDir, "circular_a.luau");

    // Should find both circular_a and circular_b without infinite loop
    REQUIRE(deps.size() == 2);

    // Entry point should be first
    CHECK(deps[0] == "circular_a.luau");

    // Both files should be in the list
    bool hasA = std::find(deps.begin(), deps.end(), "circular_a.luau") != deps.end();
    bool hasB = std::find(deps.begin(), deps.end(), "circular_b.luau") != deps.end();

    CHECK(hasA);
    CHECK(hasB);
}

TEST_CASE("staticrequiretracer_no_dependencies")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");

    StaticRequireTracer tracer;
    std::vector<std::string> deps = tracer.trace(testDir, "utils.luau");

    // utils.luau has no requires, should only return itself
    REQUIRE(deps.size() == 1);
    CHECK(deps[0] == "utils.luau");
}

TEST_CASE("staticrequiretracer_relative_paths")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");

    StaticRequireTracer tracer;
    std::vector<std::string> deps = tracer.trace(testDir, "lib/helper.luau");

    // helper.luau requires ../shared, should resolve correctly
    REQUIRE(deps.size() == 2);

    CHECK(deps[0] == "lib/helper.luau");

    bool hasShared = std::find(deps.begin(), deps.end(), "shared.luau") != deps.end();
    CHECK(hasShared);
}

TEST_CASE("staticrequiretracer_require_graph")
{
    std::string luteProjectRoot = getLuteProjectRootAbsolute();
    std::string testDir = joinPaths(luteProjectRoot, "tests/src/staticrequires");

    StaticRequireTracer tracer;
    std::vector<std::string> deps = tracer.trace(testDir, "main.luau");

    const auto& graph = tracer.getRequireGraph();

    // main.luau should require utils.luau and lib/helper.luau
    REQUIRE(graph.count("main.luau") == 1);
    const auto& mainDeps = graph.at("main.luau");
    REQUIRE(mainDeps.size() == 2);
    CHECK(std::find(mainDeps.begin(), mainDeps.end(), "utils.luau") != mainDeps.end());
    CHECK(std::find(mainDeps.begin(), mainDeps.end(), "lib/helper.luau") != mainDeps.end());

    // lib/helper.luau should require shared.luau
    REQUIRE(graph.count("lib/helper.luau") == 1);
    const auto& helperDeps = graph.at("lib/helper.luau");
    REQUIRE(helperDeps.size() == 1);
    CHECK(helperDeps[0] == "shared.luau");

    // utils.luau should have no dependencies
    REQUIRE(graph.count("utils.luau") == 1);
    const auto& utilsDeps = graph.at("utils.luau");
    CHECK(utilsDeps.empty());

    // shared.luau should have no dependencies
    REQUIRE(graph.count("shared.luau") == 1);
    const auto& sharedDeps = graph.at("shared.luau");
    CHECK(sharedDeps.empty());
}
