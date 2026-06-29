#include "debugfixture.h"
#include "doctest.h"

TEST_SUITE("Debug")
{
    TEST_CASE_FIXTURE(DebugFixture, "Debug_addBreakpoint")
    {
        std::string fixturePath = getDebugFixturePath("simple.luau");
        debug::Target target(*runtime, fixturePath);

        // valid breakpoint
        debug::Breakpoint bp = target.addBreakpoint(fixturePath, 2);
        // invalid breakpoint
        debug::Breakpoint bp2 = target.addBreakpoint(fixturePath, 100);
        // breakpoint that will be moved on installation due to whitespace
        debug::Breakpoint bp3 = target.addBreakpoint(fixturePath, 3);

        // check breakpoints before launch
        CHECK(bp.id == 0);
        CHECK(bp.sourcePath == fixturePath);
        CHECK(bp.line == 2);
        CHECK(bp.status == debug::BreakpointStatus::Pending);

        CHECK(bp2.id == 1);
        CHECK(bp2.sourcePath == fixturePath);
        CHECK(bp2.line == 100);
        CHECK(bp2.status == debug::BreakpointStatus::Pending);

        CHECK(bp3.id == 2);
        CHECK(bp3.sourcePath == fixturePath);
        CHECK(bp3.line == 3);
        CHECK(bp3.status == debug::BreakpointStatus::Pending);

        std::optional<debug::Breakpoint> found = target.getBreakpointById(0);
        REQUIRE(found.has_value());
        CHECK(found->id == 0);
        found = target.getBreakpointById(999);
        REQUIRE(!found.has_value());

        bool launched = target.launch({});
        CHECK(launched == true);

        // check breakpoints after launch
        CHECK(target.getBreakpoints().size() == 3);
        CHECK(target.getBreakpointsByStatus(debug::BreakpointStatus::Pending).size() == 0);
        CHECK(target.getBreakpointsByStatus(debug::BreakpointStatus::Installed).size() == 2);
        CHECK(target.getBreakpointsByStatus(debug::BreakpointStatus::Invalid).size() == 1);

        std::optional<debug::Breakpoint> postLaunch = target.getBreakpointById(0);
        REQUIRE(postLaunch.has_value());
        CHECK(postLaunch->status == debug::BreakpointStatus::Installed);
        CHECK(postLaunch->line == 2);

        postLaunch = target.getBreakpointById(1);
        REQUIRE(postLaunch.has_value());
        CHECK(postLaunch->status == debug::BreakpointStatus::Invalid);
        CHECK(postLaunch->line == -1);

        postLaunch = target.getBreakpointById(2);
        REQUIRE(postLaunch.has_value());
        CHECK(postLaunch->status == debug::BreakpointStatus::Installed);
        CHECK(postLaunch->line == 4);

        // check that adding breakpoints after launch should be immediately installed
        debug::Breakpoint bp4 = target.addBreakpoint(fixturePath, 2);
        CHECK(target.getBreakpoints().size() == 4);
        CHECK(bp4.status == debug::BreakpointStatus::Installed);
        CHECK(bp4.line == 2);
        CHECK(bp4.id == 3);
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_removeBreakpoint")
    {
        std::string fixturePath = getDebugFixturePath("simple.luau");
        debug::Target target(*runtime, fixturePath);

        // check removing breakpoints
        debug::Breakpoint bp = target.addBreakpoint(fixturePath, 2);
        CHECK(target.getBreakpoints().size() == 1);

        bool ok = target.removeBreakpoint(0);
        CHECK(ok);
        REQUIRE(!target.getBreakpointById(0).has_value());
        CHECK(target.getBreakpoints().size() == 0);

        ok = target.removeBreakpoint(4);
        CHECK(!ok);
    }
}
