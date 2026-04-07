// Simplified tests for module resolver functionality using public APIs.
#include "lute/common.h"
#include "lute/resolvemodule.h"
#include "lute/tcmoduleresolver.h"

#include "Luau/Ast.h"
#include "Luau/FileUtils.h"
#include "Luau/TypeCheckLimits.h"

#include <string>

#include "doctest.h"
#include "luteprojectroot.h"
#include "testreporter.h"

TEST_CASE("moduleresolver_read_source")
{
    std::string root = getLuteProjectRootAbsolute();
    std::string file = joinPaths(root, "tests/src/resolver/mainmodule.luau");
    TestReporter reporter;
    Luau::LuteTypeCheckModuleResolver resolver{reporter};
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

TEST_CASE("moduleresolver_resolveModule")
{
    std::string root = getLuteProjectRootAbsolute();
    std::string mainLuau = "@" + joinPaths(root, "tests/src/resolver/mainmodule.luau");

    TestReporter reporter;
    Luau::LuteTypeCheckModuleResolver resolver{reporter};

    Luau::ModuleInfo context;
    context.name = mainLuau;

    Luau::TypeCheckLimits limits;

    SUBCASE("resolves_std_module")
    {
        std::string path = "@std/process";
        Luau::AstArray<char> value{path.data(), path.size()};
        Luau::AstExprConstantString strNode(Luau::Location{}, value, Luau::AstExprConstantString::QuotedSimple);

        auto result = resolver.resolveModule(&context, &strNode, limits);

        REQUIRE(result.has_value());
        CHECK(result->name == "@std/process.luau");
        CHECK(reporter.getErrors().empty());
    }

    SUBCASE("caches_resolved_module_source")
    {
        std::string path = "@std/process";
        Luau::AstArray<char> value{path.data(), path.size()};
        Luau::AstExprConstantString strNode(Luau::Location{}, value, Luau::AstExprConstantString::QuotedSimple);

        resolver.resolveModule(&context, &strNode, limits);

        CHECK(resolver.sourceCache.find("@std/process.luau") != nullptr);
    }

    SUBCASE("fails_for_nonexistent_module")
    {
        std::string path = "@std/does_not_exist";
        Luau::AstArray<char> value{path.data(), path.size()};
        Luau::AstExprConstantString strNode(Luau::Location{}, value, Luau::AstExprConstantString::QuotedSimple);

        auto result = resolver.resolveModule(&context, &strNode, limits);

        CHECK(!result.has_value());
        REQUIRE(!reporter.getErrors().empty());
        CHECK(reporter.getErrors()[0].find("Failed to resolve require") != std::string::npos);
    }

    SUBCASE("fails_for_self_from_userland")
    {
        std::string path = "@self/platform";
        Luau::AstArray<char> value{path.data(), path.size()};
        Luau::AstExprConstantString strNode(Luau::Location{}, value, Luau::AstExprConstantString::QuotedSimple);

        auto result = resolver.resolveModule(&context, &strNode, limits);

        CHECK(!result.has_value());
        REQUIRE(!reporter.getErrors().empty());
    }

    SUBCASE("fails_for_non_string_require")
    {
        Luau::AstExprConstantNil nilNode(Luau::Location{});

        auto result = resolver.resolveModule(&context, &nilNode, limits);

        CHECK(!result.has_value());
        CHECK(reporter.getErrors().empty());
    }
}
