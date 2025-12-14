#include "lute/climain.h"

#include "Luau/FileUtils.h"

#include "doctest.h"
#include "lutefixture.h"
#include "luteprojectroot.h"

#include <string>
#include <vector>

TEST_CASE_FIXTURE(LuteFixture, "vm_create_child_vm_loads_lute_modules")
{
    char executablePlaceholder[] = "lute";

    for (const std::string& luteProjectRoot : {getLuteProjectRootRelative(), getLuteProjectRootAbsolute()})
    {
        std::string requirer = joinPaths(luteProjectRoot, "tests/src/vm/vm_requirer.luau");
        std::vector<char*> argv = {executablePlaceholder, requirer.data()};

        CHECK_EQ(cliMain(argv.size(), argv.data(), getReporter()), 0);
    }
}
