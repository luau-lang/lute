#include <chrono>
#include <future>

#include "debugfixture.h"
#include "doctest.h"

TEST_SUITE("Debug")
{
    TEST_CASE_FIXTURE(DebugFixture, "Debug_setBreakpoint")
    {
        std::string fixturePath = getDebugFixturePath("simple.luau");
        debug::Target target(*runtime, fixturePath);

        // valid breakpoint
        debug::Breakpoint bp = target.setBreakpoint(fixturePath, 2);
        // invalid breakpoint
        debug::Breakpoint bp2 = target.setBreakpoint(fixturePath, 100);
        // breakpoint that will be moved on installation due to whitespace
        debug::Breakpoint bp3 = target.setBreakpoint(fixturePath, 3);

        // check breakpoints before launch
        CHECK(bp.id == 0);
        CHECK(bp.sourcePath == fixturePath);
        CHECK(bp.line == 2);
        CHECK(bp.status == debug::BreakpointStatus::PendingInstall);

        CHECK(bp2.id == 1);
        CHECK(bp2.sourcePath == fixturePath);
        CHECK(bp2.line == 100);
        CHECK(bp2.status == debug::BreakpointStatus::PendingInstall);

        CHECK(bp3.id == 2);
        CHECK(bp3.sourcePath == fixturePath);
        CHECK(bp3.line == 3);
        CHECK(bp3.status == debug::BreakpointStatus::PendingInstall);

        std::optional<debug::Breakpoint> found = target.getBreakpointById(0);
        REQUIRE(found.has_value());
        CHECK(found->id == 0);
        found = target.getBreakpointById(999);
        REQUIRE(!found.has_value());

        std::promise<debug::Breakpoint> bp4Promise;
        std::future<debug::Breakpoint> bp4Future = bp4Promise.get_future();
        std::function<void(const debug::Breakpoint& bp)> onBreakpointInstall = [&bp4Promise](const debug::Breakpoint& bp)
        {
            if (bp.id == 3)
                bp4Promise.set_value(bp);
        };

        std::function<void(debug::Process & process, const debug::Breakpoint& bp)> onBreakpointHit =
            [](debug::Process& process, const debug::Breakpoint& bp)
        {
            bool continuedProcess = process.continueProcess();
            CHECK(continuedProcess);
        };

        debug::LaunchConfig config;
        config.onBreakpointInstall = onBreakpointInstall;
        config.onBreakpointHit = onBreakpointHit;

        std::shared_ptr<debug::Process> process = target.launch({}, config);
        REQUIRE(process != nullptr);

        // check breakpoints after launch
        CHECK(target.getBreakpoints().size() == 3);
        CHECK(target.getBreakpointsByStatus(debug::BreakpointStatus::PendingInstall).size() == 0);
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

        // check that adding breakpoints after launch should be installed at some point
        debug::Breakpoint bp4 = target.setBreakpoint(fixturePath, 1);
        REQUIRE(bp4Future.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        debug::Breakpoint installedBp4 = bp4Future.get();
        CHECK(installedBp4.status == debug::BreakpointStatus::Installed);
        CHECK(installedBp4.line == 1);
        CHECK(installedBp4.id == 3);

        // check that setting breakpoints at same breakpoint returns same id
        debug::Breakpoint bp5 = target.setBreakpoint(fixturePath, 2);
        CHECK(bp5.status == debug::BreakpointStatus::Installed);
        CHECK(bp5.id == 0);
        CHECK(bp5.line == 2);
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_removeBreakpoint")
    {
        std::string fixturePath = getDebugFixturePath("simple.luau");
        debug::Target target(*runtime, fixturePath);

        // check removing pending breakpoint
        debug::Breakpoint bp = target.setBreakpoint(fixturePath, 2);
        CHECK(target.getBreakpoints().size() == 1);

        std::optional<debug::Breakpoint> preLaunch = target.getBreakpointById(bp.id);
        REQUIRE(preLaunch.has_value());
        CHECK(preLaunch->status == debug::BreakpointStatus::PendingInstall);

        bool removedBp1 = target.removeBreakpoint(bp.id);
        CHECK(removedBp1);
        REQUIRE(!target.getBreakpointById(bp.id).has_value());
        CHECK(target.getBreakpoints().size() == 0);

        // check removing installed breakpoints and invalid breakpoints
        debug::Breakpoint bp2 = target.setBreakpoint(fixturePath, 3);
        debug::Breakpoint bp3 = target.setBreakpoint(fixturePath, 100);
        CHECK(target.getBreakpoints().size() == 2);

        // We can do things like trigger breakpoint removals when our breakpoint is paused.
        int numUninstalledBps = 0;
        std::promise<debug::Breakpoint> bp2Promise;
        std::future<debug::Breakpoint> bp2Future = bp2Promise.get_future();
        std::function<void(const debug::Breakpoint& bp)> onBreakpointUninstall = [&numUninstalledBps, &bp2Promise](const debug::Breakpoint& bp)
        {
            numUninstalledBps++;
            if (bp.id == 1)
            {
                bp2Promise.set_value(bp);
            }
        };

        std::function<void(debug::Process & process, const debug::Breakpoint& bp)> onBreakpointHit =
            [](debug::Process& process, const debug::Breakpoint& bp)
        {
            debug::Target& target = process.getTarget();
            std::optional<debug::Breakpoint> postLaunch = target.getBreakpointById(bp.id);
            REQUIRE(postLaunch.has_value());
            CHECK(postLaunch->status == debug::BreakpointStatus::Installed);

            bool removedBp2 = target.removeBreakpoint(bp.id);
            CHECK(removedBp2);
            std::optional<debug::Breakpoint> postRemoval = target.getBreakpointById(bp.id);
            REQUIRE(postRemoval.has_value());
            CHECK(postRemoval->status == debug::BreakpointStatus::PendingUninstall);

            bool continuedProcess = process.continueProcess();
            CHECK(continuedProcess);
        };

        debug::LaunchConfig config;
        config.onBreakpointUninstall = onBreakpointUninstall;
        config.onBreakpointHit = onBreakpointHit;
        std::shared_ptr<debug::Process> process = target.launch({}, config);
        REQUIRE(process != nullptr);
        std::optional<debug::Breakpoint> postLaunch = target.getBreakpointById(bp3.id);
        REQUIRE(postLaunch.has_value());
        CHECK(postLaunch->status == debug::BreakpointStatus::Invalid);

        bool removedBp3 = target.removeBreakpoint(bp3.id);
        CHECK(removedBp3);
        CHECK(!target.getBreakpointById(bp3.id).has_value());

        // check installed breakpoint is actually uninstalled
        REQUIRE(bp2Future.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(numUninstalledBps == 1);
        CHECK(!target.getBreakpointById(bp2.id).has_value());

        // check cannot remove never added breakpoint
        bool cannotRemove = target.removeBreakpoint(100);
        CHECK(!cannotRemove);
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_hitBreakpoint")
    {
        std::string fixturePath = getDebugFixturePath("loop.luau");
        debug::Target target(*runtime, fixturePath);

        // check removing pending breakpoint
        debug::Breakpoint bp1 = target.setBreakpoint(fixturePath, 4);
        debug::Breakpoint bp2 = target.setBreakpoint(fixturePath, 6);

        int hitBp1 = 0, hitBp2 = 0;
        std::function<void(debug::Process & process, const debug::Breakpoint& bp)> onBreakpointHit =
            [bp1, bp2, &hitBp1, &hitBp2](debug::Process& process, const debug::Breakpoint& hitBp)
        {
            if (hitBp.id == bp1.id)
            {
                hitBp1++;
            }
            if (hitBp.id == bp2.id)
            {
                hitBp2++;
            }
            process.continueProcess();
        };

        std::promise<bool> exitPromise;
        std::future<bool> exitFuture = exitPromise.get_future();

        debug::LaunchConfig config;
        config.onBreakpointHit = onBreakpointHit;
        config.onExit = [&exitPromise](bool success)
        {
            exitPromise.set_value(success);
        };
        target.launch({}, config);

        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(exitFuture.get() == true);
        CHECK(hitBp1 == 5);
        CHECK(hitBp2 == 25);
    }
}
