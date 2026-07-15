#include <chrono>
#include <future>
#include <thread>

#include "debugfixture.h"
#include "doctest.h"

static void checkBreakpoint(debug::Target& target, int id, debug::BreakpointStatus status, int line)
{
    auto foundBp = target.getBreakpointById(id);
    REQUIRE(foundBp.has_value());
    CHECK(foundBp->id == id);
    CHECK(foundBp->status == status);
    CHECK(foundBp->line == line);
}

TEST_SUITE("Debug")
{
    TEST_CASE_FIXTURE(DebugFixture, "Debug_setBreakpoint")
    {
        std::string fixturePath = getDebugFixturePath("simple.luau");
        debug::Target target(*runtime);

        // valid breakpoint
        debug::Breakpoint bp = target.setBreakpoint(fixturePath, 2);
        // invalid breakpoint
        debug::Breakpoint bp2 = target.setBreakpoint(fixturePath, 100);
        // breakpoint that will be moved on installation due to whitespace
        debug::Breakpoint bp3 = target.setBreakpoint(fixturePath, 3);

        // check breakpoints before launch
        CHECK(bp.id == 0);
        checkBreakpoint(target, bp.id, debug::BreakpointStatus::PendingInstall, 2);
        CHECK(bp2.id == 1);
        checkBreakpoint(target, bp2.id, debug::BreakpointStatus::PendingInstall, 100);
        CHECK(bp3.id == 2);
        checkBreakpoint(target, bp3.id, debug::BreakpointStatus::PendingInstall, 3);

        // check cannot find not-set breakpoint
        std::optional<debug::Breakpoint> found = target.getBreakpointById(999);
        REQUIRE(!found.has_value());

        std::promise<void> bp4Promise;
        std::future<void> bp4Future = bp4Promise.get_future();
        std::function<void(const debug::Breakpoint& bp)> onBreakpointInstall = [&](const debug::Breakpoint& bp)
        {
            if (bp.id == 3)
                bp4Promise.set_value();
        };

        std::function<void(const debug::Breakpoint& bp)> onBreakpointHit = [&](const debug::Breakpoint& bp)
        {
            bool continuedProcess = target.continueProcess();
            CHECK(continuedProcess);
        };

        config.onBreakpointInstall = onBreakpointInstall;
        config.onBreakpointHit = onBreakpointHit;

        bool launched = target.launch(fixturePath, {}, config);
        CHECK(launched);

        // check breakpoints before launch are immediately installed after launch
        CHECK(target.getBreakpoints().size() == 3);
        CHECK(target.getBreakpointsByStatus(debug::BreakpointStatus::PendingInstall).size() == 0);
        CHECK(target.getBreakpointsByStatus(debug::BreakpointStatus::Installed).size() == 2);
        CHECK(target.getBreakpointsByStatus(debug::BreakpointStatus::Invalid).size() == 1);
        checkBreakpoint(target, bp.id, debug::BreakpointStatus::Installed, 2);
        checkBreakpoint(target, bp2.id, debug::BreakpointStatus::Invalid, -1);
        checkBreakpoint(target, bp3.id, debug::BreakpointStatus::Installed, 4);

        // check that adding breakpoints after launch should be installed at some point
        debug::Breakpoint bp4 = target.setBreakpoint(fixturePath, 1);
        REQUIRE(bp4Future.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        checkBreakpoint(target, bp4.id, debug::BreakpointStatus::Installed, 1);

        // check that setting breakpoints at same breakpoint returns same id
        debug::Breakpoint bp5 = target.setBreakpoint(fixturePath, 2);
        CHECK(bp5.id == 0);
        checkBreakpoint(target, bp5.id, debug::BreakpointStatus::Installed, 2);

        // wait until script is finished to call destructors
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_removeBreakpoint")
    {
        std::string fixturePath = getDebugFixturePath("simple.luau");
        debug::Target target(*runtime);

        // check removing pending breakpoint
        debug::Breakpoint bp = target.setBreakpoint(fixturePath, 2);
        CHECK(target.getBreakpoints().size() == 1);
        checkBreakpoint(target, bp.id, debug::BreakpointStatus::PendingInstall, 2);
        bool removedBp1 = target.removeBreakpoint(bp.id);
        CHECK(removedBp1);
        REQUIRE(!target.getBreakpointById(bp.id).has_value());
        CHECK(target.getBreakpoints().size() == 0);

        // check removing installed breakpoints and invalid breakpoints
        debug::Breakpoint bp2 = target.setBreakpoint(fixturePath, 3);
        debug::Breakpoint bp3 = target.setBreakpoint(fixturePath, 100);
        CHECK(target.getBreakpoints().size() == 2);

        int numUninstalledBps = 0;
        std::promise<void> bp2Promise;
        std::future<void> bp2Future = bp2Promise.get_future();
        std::function<void(const debug::Breakpoint& bp)> onBreakpointUninstall = [&](const debug::Breakpoint& bp)
        {
            numUninstalledBps++;
            if (bp.id == bp2.id)
                bp2Promise.set_value();
        };

        // trigger breakpoint removals when our breakpoint is hit (thus, the execution is currently paused
        // and we can see changes to it being pending uninstall)
        std::function<void(const debug::Breakpoint& bp)> onBreakpointHit = [&](const debug::Breakpoint& bp)
        {
            checkBreakpoint(target, bp.id, debug::BreakpointStatus::Installed, bp.line);

            bool removedBp2 = target.removeBreakpoint(bp.id);
            CHECK(removedBp2);
            REQUIRE(!target.getBreakpointById(bp.id).has_value());

            bool continuedProcess = target.continueProcess();
            CHECK(continuedProcess);
        };

        config.onBreakpointUninstall = onBreakpointUninstall;
        config.onBreakpointHit = onBreakpointHit;
        bool launched = target.launch(fixturePath, {}, config);
        CHECK(launched);

        checkBreakpoint(target, bp3.id, debug::BreakpointStatus::Invalid, -1);
        // check invalid breakpoint is installed instantenously
        bool removedBp3 = target.removeBreakpoint(bp3.id);
        CHECK(removedBp3);
        CHECK(!target.getBreakpointById(bp3.id).has_value());

        // check installed breakpoint is actually uninstalled by hitting the breakpoint
        REQUIRE(bp2Future.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(numUninstalledBps == 1);
        CHECK(!target.getBreakpointById(bp2.id).has_value());

        // check cannot remove never added breakpoint
        bool cannotRemove = target.removeBreakpoint(100);
        CHECK(!cannotRemove);

        // wait until script is finished to call destructors
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_hitBreakpoint")
    {
        std::string fixturePath = getDebugFixturePath("loop.luau");
        debug::Target target(*runtime);

        debug::Breakpoint bp1 = target.setBreakpoint(fixturePath, 4);
        debug::Breakpoint bp2 = target.setBreakpoint(fixturePath, 6);
        // bp3 checks that removing a breakpoint makes sure that breakpoint is never hit again
        debug::Breakpoint bp3 = target.setBreakpoint(fixturePath, 7);
        int hitBp1 = 0, hitBp2 = 0, hitBp3 = 0;

        std::function<void(const debug::Breakpoint& bp)> onBreakpointHit = [&](const debug::Breakpoint& hitBp)
        {
            if (hitBp.id == bp1.id)
                hitBp1++;
            if (hitBp.id == bp2.id)
                hitBp2++;
            if (hitBp.id == bp3.id)
            {
                hitBp3++;
                target.removeBreakpoint(bp3.id);
            }
            target.continueProcess();
        };

        config.onBreakpointHit = onBreakpointHit;
        target.launch(fixturePath, {}, config);

        // wait until script is finished
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(exitFuture.get() == true);
        CHECK(hitBp1 == 5);
        CHECK(hitBp2 == 25);
        CHECK(hitBp3 == 1);
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_pausesOnBreakpoint")
    {
        std::string fixturePath = getDebugFixturePath("simple.luau");
        debug::Target target(*runtime);
        debug::Breakpoint bp1 = target.setBreakpoint(fixturePath, 1);
        debug::Breakpoint bp2 = target.setBreakpoint(fixturePath, 2);

        std::promise<void> hitPromise1;
        std::future<void> hitFuture1 = hitPromise1.get_future();
        std::promise<void> hitPromise2;
        std::future<void> hitFuture2 = hitPromise2.get_future();

        config.onBreakpointHit = [&](const debug::Breakpoint& bp)
        {
            if (bp.id == bp1.id)
                hitPromise1.set_value();
            else if (bp.id == bp2.id)
                hitPromise2.set_value();
        };

        bool launched = target.launch(fixturePath, {}, config);
        CHECK(launched);
        // check we have hit the breakpoint 1
        REQUIRE(hitFuture1.wait_for(std::chrono::seconds(2)) == std::future_status::ready);
        // check that we actually stopped at the breakpoint by having not hit the next breakpoint
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        REQUIRE(hitFuture2.wait_for(std::chrono::seconds(0)) == std::future_status::timeout);

        // continue execution
        bool continuedProcess = target.continueProcess();
        CHECK(continuedProcess);

        // check we have hit the breakpoint 2
        REQUIRE(hitFuture2.wait_for(std::chrono::seconds(2)) == std::future_status::ready);
        // check that we actually stopped at the breakpoint by having not hit the exit
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(0)) == std::future_status::timeout);

        // continue execution
        continuedProcess = target.continueProcess();
        CHECK(continuedProcess);
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
    }
}
