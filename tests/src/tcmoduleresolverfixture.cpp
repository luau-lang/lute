#include "tcmoduleresolverfixture.h"

#include "Luau/FileUtils.h"

#include "luteprojectroot.h"

TCModuleResolverFixture::TCModuleResolverFixture()
    : resolver(getReporter())
{
    std::string root = getLuteProjectRootAbsolute();
    context.name = "@" + joinPaths(root, "tests/src/resolver/mainmodule.luau");
}

