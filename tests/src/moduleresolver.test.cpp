// Simplified tests for module resolver functionality using public APIs.
#include "lute/moduleresolver.h"

#include "lute/resolvemodule.h"

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

// TODO: add tests for resolveModule
