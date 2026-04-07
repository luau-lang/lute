// Simplified tests for module resolver functionality using public APIs.
#include "lute/common.h"
#include "lute/resolvemodule.h"

#include "Luau/FileUtils.h"

#include <string>

#include "doctest.h"
#include "luteprojectroot.h"
#include "tcmoduleresolverfixture.h"

static Luau::AstExprConstantString makeStringNode(std::string path)
{
    Luau::AstArray<char> value{path.data(), path.size()};
    return Luau::AstExprConstantString(Luau::Location{}, value, Luau::AstExprConstantString::QuotedSimple);
}

TEST_CASE_FIXTURE(TCModuleResolverFixture, "moduleresolver_readSource")
{
    std::string root = getLuteProjectRootAbsolute();
    std::string file = joinPaths(root, "tests/src/resolver/mainmodule.luau");
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

TEST_CASE_FIXTURE(TCModuleResolverFixture, "moduleresolver_resolveModule")
{
    SUBCASE("resolves_std_module")
    {
        auto strNode = makeStringNode("@std/process");
        auto result = resolver.resolveModule(&context, &strNode, limits);

        REQUIRE(result.has_value());
        CHECK(result->name == "@std/process.luau");
        CHECK(getReporter().getErrors().empty());
    }

    SUBCASE("caches_resolved_module_source")
    {
        auto strNode = makeStringNode("@std/process");
        resolver.resolveModule(&context, &strNode, limits);

        CHECK(resolver.sourceCache.find("@std/process.luau") != nullptr);
    }

    SUBCASE("fails_for_nonexistent_module")
    {
        auto strNode = makeStringNode("@std/does_not_exist");
        auto result = resolver.resolveModule(&context, &strNode, limits);

        CHECK(!result.has_value());
        REQUIRE(!getReporter().getErrors().empty());
        CHECK(getReporter().getErrors()[0].find("Failed to resolve require") != std::string::npos);
    }

    SUBCASE("fails_for_self_from_userland")
    {
        auto strNode = makeStringNode("@self/platform");
        auto result = resolver.resolveModule(&context, &strNode, limits);

        CHECK(!result.has_value());
        REQUIRE(!getReporter().getErrors().empty());
    }

    SUBCASE("returns_nullopt_silently_for_non_string_expr")
    {
        Luau::AstExprConstantNil nilNode(Luau::Location{});

        auto result = resolver.resolveModule(&context, &nilNode, limits);

        CHECK(!result.has_value());
        CHECK(getReporter().getErrors().empty());
    }
}
