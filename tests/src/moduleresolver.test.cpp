// Simplified tests for module resolver functionality using public APIs.
#include "lute/common.h"
#include "lute/resolvemodule.h"
#include "lute/tcmoduleresolver.h"

#include "Luau/Ast.h"
#include "Luau/FileUtils.h"

#include <string>

#include "doctest.h"
#include "luteprojectroot.h"

TEST_CASE("moduleresolver_read_source")
{
    std::string root = getLuteProjectRootAbsolute();
    std::string file = joinPaths(root, "tests/src/resolver/mainmodule.luau");
    Luau::LuteTypeCheckModuleResolver resolver;
    auto source = resolver.readSource(file);
    REQUIRE(source);
    CHECK(source->type == Luau::SourceCode::Module);
    CHECK(source->source.find("require") != std::string::npos);
}

TEST_CASE("moduleresolver_resolve_for_typecheck")
{
    std::string root = getLuteProjectRootAbsolute();
    std::string mainLuau = "@" + joinPaths(root, "tests/src/resolver/mainmodule.luau");
    std::string error;

    SUBCASE("resolve_std")
    {
        auto resolved = resolveForTypeCheck("@std/process", mainLuau, &error);
        REQUIRE(resolved);
        CHECK(resolved->path == "@std/process.luau");
    }

    SUBCASE("resolve_batteries")
    {
        auto resolved = resolveForTypeCheck("@batteries/base64", mainLuau, &error);
        if (resolved)
        {
            REQUIRE_FALSE_MESSAGE(false, "This shouldn't resolve successfully - you might need to delete the .luaurc and replace it with the .luaurc.ci");
        }
        CHECK(!error.empty());
        CHECK(!resolved.has_value());
    }

    SUBCASE("resolve_self_in_std")
    {
        auto resolved = resolveForTypeCheck("@self/platform", "@std/system/init.luau", &error);
        REQUIRE(resolved);
        CHECK(resolved->path == "@std/system/platform.luau");
    }

    SUBCASE("resolve_lute_from_std")
    {
        auto resolved = resolveForTypeCheck("@lute/process", "@std/process.luau", &error);
        REQUIRE(resolved);
        CHECK(resolved->path == "@lute/process.luau");
    }

    SUBCASE("resolve_std_from_batteries")
    {
        auto resolved = resolveForTypeCheck("@std/process", "@batteries/base64.luau", &error);
        REQUIRE(resolved);
        CHECK(resolved->path == "@std/process.luau");
    }

    SUBCASE("resolve_batteries_from_std")
    {
        auto resolved = resolveForTypeCheck("@batteries/collections/deque", "@std/fs.luau", &error);
        REQUIRE(resolved);
        CHECK(resolved->path == "@batteries/collections/deque.luau");
    }

    SUBCASE("resolve_nonexistent_std")
    {
        auto resolved = resolveForTypeCheck("@std/does_not_exist", mainLuau, &error);
        CHECK(!resolved);
    }

    SUBCASE("resolve_self_from_userland")
    {
        // @self only works from within an existing library like @std or @batteries
        auto resolved = resolveForTypeCheck("@self/platform", mainLuau, &error);
        CHECK(!resolved);
    }
}

TEST_CASE("moduleresolver_typecheck_resolve")
{
    std::string root = getLuteProjectRootAbsolute();
    std::string mainLuau = "@" + joinPaths(root, "tests/src/resolver/mainmodule.luau");
    std::string error;
    auto resolved = resolveForTypeCheck("@std/process", mainLuau, &error);
    REQUIRE(resolved);
    CHECK(resolved->path == "@std/process.luau");
    CHECK(resolved->source.find("processlib") != std::string::npos);
}
