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

        // check removing pending breakpoint
        debug::Breakpoint bp = target.addBreakpoint(fixturePath, 2);
        CHECK(target.getBreakpoints().size() == 1);

        std::optional<debug::Breakpoint> preLaunch = target.getBreakpointById(bp.id);
        REQUIRE(preLaunch.has_value());
        CHECK(preLaunch->status == debug::BreakpointStatus::Pending);

        bool removedBp1 = target.removeBreakpoint(bp.id);
        CHECK(removedBp1);
        REQUIRE(!target.getBreakpointById(bp.id).has_value());
        CHECK(target.getBreakpoints().size() == 0);

        // check removing installed breakpoints and invalid breakpoints
        debug::Breakpoint bp2 = target.addBreakpoint(fixturePath, 3);
        debug::Breakpoint bp3 = target.addBreakpoint(fixturePath, 100);
        CHECK(target.getBreakpoints().size() == 2);
        bool launched = target.launch({});
        CHECK(launched == true);

        std::optional<debug::Breakpoint> postLaunch = target.getBreakpointById(bp2.id);
        REQUIRE(postLaunch.has_value());
        CHECK(postLaunch->status == debug::BreakpointStatus::Installed);

        bool removedBp2 = target.removeBreakpoint(bp2.id);
        CHECK(removedBp2);
        REQUIRE(!target.getBreakpointById(bp2.id).has_value());
        CHECK(target.getBreakpoints().size() == 1);

        postLaunch = target.getBreakpointById(bp3.id);
        REQUIRE(postLaunch.has_value());
        CHECK(postLaunch->status == debug::BreakpointStatus::Invalid);

        bool removedBp3 = target.removeBreakpoint(bp3.id);
        CHECK(removedBp3);
        REQUIRE(!target.getBreakpointById(bp3.id).has_value());
        CHECK(target.getBreakpoints().size() == 0);

        // check cannot remove never added breakpoint
        bool cannotRemove = target.removeBreakpoint(100);
        CHECK(!cannotRemove);
    }
}
