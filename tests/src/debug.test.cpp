#include "lute/debuginternals.h"

#include <chrono>
#include <future>
#include <thread>

#include "debugfixture.h"
#include "doctest.h"

using namespace debug;

static void checkBreakpointId(Target& target, int id, BreakpointStatus status, std::string sourcePath, int line)
{
    std::optional<Breakpoint> foundBp = target.getBreakpointById(id);
    REQUIRE(foundBp.has_value());
    CHECK(foundBp->id == id);
    CHECK(foundBp->status == status);
    CHECK(foundBp->line == line);
    CHECK(foundBp->sourcePath == sourcePath);
}

static void checkBreakpointSourceLine(Target& target, int id, BreakpointStatus status, std::string sourcePath, int line)
{
    std::optional<Breakpoint> foundBp = target.getBreakpointBySourceLine(sourcePath, line);
    REQUIRE(foundBp.has_value());
    CHECK(foundBp->id == id);
    CHECK(foundBp->status == status);
    CHECK(foundBp->line == line);
    CHECK(foundBp->sourcePath == sourcePath);
}

TEST_SUITE("Debug")
{
    TEST_CASE_FIXTURE(DebugFixture, "Debug_setBreakpoint")
    {
        std::string fixturePath = getDebugFixturePath("simple.luau");
        Target target(*runtime);

        // valid breakpoint
        Breakpoint bp = target.setBreakpoint(fixturePath, 2);
        // invalid breakpoint
        Breakpoint bp2 = target.setBreakpoint(fixturePath, 100);
        // breakpoint that will be moved on installation due to whitespace
        Breakpoint bp3 = target.setBreakpoint(fixturePath, 3);

        // check breakpoints before launch
        CHECK(bp.id == 1);
        checkBreakpointId(target, bp.id, BreakpointStatus::PendingInstall, fixturePath, 2);
        CHECK(bp2.id == 2);
        checkBreakpointId(target, bp2.id, BreakpointStatus::PendingInstall, fixturePath, 100);
        CHECK(bp3.id == 3);
        checkBreakpointId(target, bp3.id, BreakpointStatus::PendingInstall, fixturePath, 3);

        // check cannot find not-set breakpoint
        std::optional<Breakpoint> found = target.getBreakpointById(999);
        REQUIRE(!found.has_value());

        std::promise<void> bp4InstalledPromise, bp4AddedPromise;
        std::future<void> bp4InstalledFuture = bp4InstalledPromise.get_future();
        std::future<void> bp4AddedFuture = bp4AddedPromise.get_future();

        std::function<void(const Breakpoint& bp)> onBreakpointInstall = [&](const Breakpoint& bp)
        {
            if (bp.id == 4)
                bp4InstalledPromise.set_value();
        };

        std::function<void(const Thread&, const Breakpoint& bp)> onBreakpointHit = [&](const Thread&, const Breakpoint& bp)
        {
            // we wait until bp4 is added; otherwise we can get an error
            // where the program terminates before bp4 is added
            REQUIRE(bp4AddedFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
            bool continuedProcess = target.continueProcess();
            CHECK(continuedProcess);
        };

        config.onBreakpointInstall = onBreakpointInstall;
        config.onBreakpointHit = onBreakpointHit;

        bool launched = target.launch(fixturePath, {}, config);
        CHECK(launched);

        // check breakpoints before launch are immediately installed after launch
        CHECK(target.getBreakpoints().size() == 3);
        CHECK(target.getBreakpointsByStatus(BreakpointStatus::PendingInstall).size() == 0);
        CHECK(target.getBreakpointsByStatus(BreakpointStatus::Installed).size() == 2);
        CHECK(target.getBreakpointsByStatus(BreakpointStatus::Invalid).size() == 1);
        checkBreakpointId(target, bp.id, BreakpointStatus::Installed, fixturePath, 2);
        checkBreakpointId(target, bp2.id, BreakpointStatus::Invalid, fixturePath, -1);
        checkBreakpointId(target, bp3.id, BreakpointStatus::Installed, fixturePath, 4);

        // test getBreakpointBySourceLine()
        checkBreakpointSourceLine(target, bp.id, BreakpointStatus::Installed, fixturePath, 2);
        checkBreakpointSourceLine(target, bp2.id, BreakpointStatus::Invalid, fixturePath, -1);
        checkBreakpointSourceLine(target, bp3.id, BreakpointStatus::Installed, fixturePath, 4);
        CHECK(!target.getBreakpointBySourceLine(fixturePath, 3).has_value());
        CHECK(!target.getBreakpointBySourceLine(getDebugFixturePath("loop.luau"), 4).has_value());

        // check that adding breakpoints after launch should be installed at some point
        Breakpoint bp4 = target.setBreakpoint(fixturePath, 1);
        bp4AddedPromise.set_value();
        // wait until bp4 is actually installed
        REQUIRE(bp4InstalledFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        checkBreakpointId(target, bp4.id, BreakpointStatus::Installed, fixturePath, 1);

        // check that setting breakpoints at same breakpoint returns same id
        Breakpoint bp5 = target.setBreakpoint(fixturePath, 2);
        CHECK(bp5.id == 1);
        checkBreakpointId(target, bp5.id, BreakpointStatus::Installed, fixturePath, 2);

        // wait until script is finished to call destructors
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_removeBreakpoint")
    {
        std::string fixturePath = getDebugFixturePath("simple.luau");
        Target target(*runtime);

        // check removing pending breakpoint
        Breakpoint bp = target.setBreakpoint(fixturePath, 2);
        CHECK(target.getBreakpoints().size() == 1);
        checkBreakpointId(target, bp.id, BreakpointStatus::PendingInstall, fixturePath, 2);
        bool removedBp1 = target.removeBreakpoint(bp.id);
        CHECK(removedBp1);
        REQUIRE(!target.getBreakpointById(bp.id).has_value());
        CHECK(target.getBreakpoints().size() == 0);

        // check removing installed breakpoints and invalid breakpoints
        Breakpoint bp2 = target.setBreakpoint(fixturePath, 3);
        Breakpoint bp3 = target.setBreakpoint(fixturePath, 100);
        CHECK(target.getBreakpoints().size() == 2);

        int numUninstalledBps = 0;
        std::promise<void> bp2Promise;
        std::future<void> bp2Future = bp2Promise.get_future();
        std::function<void(const Breakpoint& bp)> onBreakpointUninstall = [&](const Breakpoint& bp)
        {
            numUninstalledBps++;
            if (bp.id == bp2.id)
                bp2Promise.set_value();
        };

        // trigger breakpoint removals when our breakpoint is hit (thus, the execution is currently paused
        // and we can see changes to it being pending uninstall)
        std::function<void(const Thread&, const Breakpoint& bp)> onBreakpointHit = [&](const Thread&, const Breakpoint& bp)
        {
            checkBreakpointId(target, bp.id, BreakpointStatus::Installed, fixturePath, bp.line);

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

        checkBreakpointId(target, bp3.id, BreakpointStatus::Invalid, fixturePath, -1);
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
        Target target(*runtime);

        Breakpoint bp1 = target.setBreakpoint(fixturePath, 4);
        Breakpoint bp2 = target.setBreakpoint(fixturePath, 6);
        // bp3 checks that removing a breakpoint makes sure that breakpoint is never hit again
        Breakpoint bp3 = target.setBreakpoint(fixturePath, 7);
        int hitBp1 = 0, hitBp2 = 0, hitBp3 = 0;

        std::function<void(const Thread&, const Breakpoint& bp)> onBreakpointHit = [&](const Thread&, const Breakpoint& hitBp)
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

    TEST_CASE_FIXTURE(DebugFixture, "Debug_stopOnBreakpoint")
    {
        std::string fixturePath = getDebugFixturePath("simple.luau");
        Target target(*runtime);
        Breakpoint bp1 = target.setBreakpoint(fixturePath, 1);
        Breakpoint bp2 = target.setBreakpoint(fixturePath, 2);

        std::promise<void> hitPromise1;
        std::future<void> hitFuture1 = hitPromise1.get_future();
        std::promise<void> hitPromise2;
        std::future<void> hitFuture2 = hitPromise2.get_future();

        config.onBreakpointHit = [&](const Thread&, const Breakpoint& bp)
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
        CHECK(target.getLine() == 2);
        // continue execution
        continuedProcess = target.continueProcess();
        CHECK(target.getLine() == -1);
        CHECK(continuedProcess);
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_pauseProcess")
    {
        std::string fixturePath = getDebugFixturePath("loop.luau");
        Target target(*runtime);
        target.setBreakpoint(fixturePath, 1);

        int numPause = 0;
        std::promise<void> hitPromise;
        std::future<void> hitFuture = hitPromise.get_future();
        // This tests whether we pause after continuing. This is pretty
        // strange but is unfortunately, the best way of guaranteeing that a pause request
        // goes through without timing conerns.
        config.onBreakpointHit = [&](const Thread&, const Breakpoint& bp)
        {
            bool continuedProcess = target.continueProcess();
            CHECK(continuedProcess);
            bool pausedProcess = target.pauseProcess();
            CHECK(pausedProcess);
            hitPromise.set_value();
        };
        config.onPause = [&](const Thread&)
        {
            numPause++;
        };
        bool launched = target.launch(fixturePath, {}, config);
        CHECK(launched);
        // we hit the breakpoint and should be paused now.
        REQUIRE(hitFuture.wait_for(std::chrono::seconds(2)) == std::future_status::ready);
        std::this_thread::sleep_for(std::chrono::seconds(1));
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(0)) == std::future_status::timeout);
        CHECK(numPause == 1);
        // The pause should stop right after we finish the last line of the inner for loop.
        CHECK(target.getLine() == 5);
        bool continuedProcess = target.continueProcess();
        CHECK(continuedProcess);
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_destroyInfiniteLoop")
    {
        // This tests that we don't stall on the Runtime destruction even when we are running
        // an infinite loop.
        std::string fixturePath = getDebugFixturePath("infiniteloop.luau");

        std::future<void> destroyFuture = std::async(
            std::launch::async,
            [&]()
            {
                Target target(*runtime);
                target.launch(fixturePath, {}, config);
                // This is a timing pause to make sure that we actually start execution of the script.
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
                // At this point target and its Runtime should be destroyed.
            }
        );
        REQUIRE(destroyFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_multiSource")
    {
        std::string mainPath = getDebugFixturePath("require_main.luau");
        std::string triangPath = getDebugFixturePath("require_triang.luau");

        int bpHit1 = 0, bpHit2 = 0, bpInstalled = 0;
        Target target(*runtime);
        Breakpoint bp1 = target.setBreakpoint(mainPath, 5);
        Breakpoint bp2 = target.setBreakpoint(triangPath, 5);
        config.onBreakpointInstall = [&](const Breakpoint& bp)
        {
            bpInstalled++;
        };
        config.onBreakpointHit = [&](const Thread&, const Breakpoint& bp)
        {
            if (bp.id == bp1.id)
                bpHit1++;
            else if (bp.id == bp2.id)
                bpHit2++;
            target.continueProcess();
        };
        bool launched = target.launch(mainPath, {}, config);
        CHECK(launched);
        // check we are done
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(bpHit1 == 5);
        CHECK(bpHit2 == 15);
        CHECK(bpInstalled == 2);
        std::vector<std::string> sources = target.getLoadedSources();
        CHECK(sources.size() == 2);
        CHECK(std::find(sources.begin(), sources.end(), mainPath) != sources.end());
        CHECK(std::find(sources.begin(), sources.end(), triangPath) != sources.end());
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_printReplace")
    {
        std::string fixturePath = getDebugFixturePath("print.luau");
        Target target(*runtime);
        std::vector<std::pair<std::string, int>> prints;
        config.onPrint = [&](std::string message, std::string source, int line)
        {
            prints.emplace_back(std::make_pair(message, line));
            CHECK(source == fixturePath);
        };
        bool launched = target.launch(fixturePath, {}, config);
        CHECK(launched);
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(prints.size() == 2);
        CHECK(prints[0] == std::make_pair(std::string("3\tabc\tfalse\n"), 6));
        CHECK(prints[1] == std::make_pair(std::string("custom_value\n"), 7));
    }


    TEST_CASE_FIXTURE(DebugFixture, "Debug_step")
    {
        std::string mainPath = getDebugFixturePath("step.luau");
        std::string triangPath = getDebugFixturePath("require_triang.luau");


        std::promise<void> hitPromise;
        std::future<void> hitFuture = hitPromise.get_future();

        std::promise<void> stepPromise;
        std::future<void> stepFuture = stepPromise.get_future();

        Target target(*runtime);
        Breakpoint bp = target.setBreakpoint(mainPath, 9);
        config.onBreakpointHit = [&](const Breakpoint& bp)
        {
            hitPromise.set_value();
        };
        config.onStepStop = [&](const StepInfo)
        {
            stepPromise.set_value();
        };
        bool launched = target.launch(mainPath, {}, config);
        CHECK(launched);
        // check we have hit bp
        REQUIRE(hitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        // step in acts like step over when there's no function calls
        CHECK(target.getLine() == 9);
        bool stepped = target.stepIn();
        CHECK(stepped);
        REQUIRE(stepFuture.wait_for(std::chrono::seconds(1)) == std::future_status::ready);
        CHECK(target.getLine() == 10);
        stepPromise = std::promise<void>{};
        stepFuture = stepPromise.get_future();
        // step into function f
        stepped = target.stepIn();
        CHECK(stepped);
        REQUIRE(stepFuture.wait_for(std::chrono::seconds(1)) == std::future_status::ready);
        CHECK(target.getLine() == 2);
        stepPromise = std::promise<void>{};
        stepFuture = stepPromise.get_future();
        // this steps out of function to the next line in the caller
        stepped = target.stepOut();
        CHECK(stepped);
        REQUIRE(stepFuture.wait_for(std::chrono::seconds(1)) == std::future_status::ready);
        CHECK(target.getLine() == 11);
        stepPromise = std::promise<void>{};
        stepFuture = stepPromise.get_future();
        // this steps over a function
        stepped = target.stepOver();
        CHECK(stepped);
        REQUIRE(stepFuture.wait_for(std::chrono::seconds(1)) == std::future_status::ready);
        CHECK(target.getLine() == 12);
        stepPromise = std::promise<void>{};
        stepFuture = stepPromise.get_future();
        // this steps to the virtual last line
        stepped = target.stepOver();
        CHECK(stepped);
        REQUIRE(stepFuture.wait_for(std::chrono::seconds(1)) == std::future_status::ready);
        CHECK(target.getLine() == 13);
        target.stepOver();

        // check we are done
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_threadTracking")
    {
        std::string fixturePath = getDebugFixturePath("task.luau");
        Target target(*runtime);
        Breakpoint bp1 = target.setBreakpoint(fixturePath, 7);
        Breakpoint bp2 = target.setBreakpoint(fixturePath, 14);
        Breakpoint bp3 = target.setBreakpoint(fixturePath, 22);

        int maxThreadsSeen = 0;
        int hitsBp1 = 0, hitsBp2 = 0;
        config.onBreakpointHit = [&](const Thread& thread, const Breakpoint& bp)
        {
            if (bp.id == bp1.id)
            {
                CHECK(thread.id == 2);
                auto stoppedThread = target.getStoppedThread();
                REQUIRE(stoppedThread.has_value());
                CHECK(stoppedThread->id == 2);
                hitsBp1++;
                const std::vector<Thread>& threads = target.getThreads();
                maxThreadsSeen = std::max(maxThreadsSeen, (int)threads.size());
                if (threads.size() == 3)
                {
                    Thread t1(1, "Main Coroutine");
                    Thread t2(2, "Coroutine 2");
                    Thread t3(3, "Coroutine 3");
                    CHECK(std::find(threads.begin(), threads.end(), t1) != threads.end());
                    CHECK(std::find(threads.begin(), threads.end(), t2) != threads.end());
                    CHECK(std::find(threads.begin(), threads.end(), t3) != threads.end());
                }
            }
            else if (bp.id == bp2.id)
            {
                CHECK(thread.id == 3);
                auto stoppedThread = target.getStoppedThread();
                REQUIRE(stoppedThread.has_value());
                CHECK(stoppedThread->id == 3);
                hitsBp2++;
            }
            else
            {
                // after joining all threads, we only have one left over (the main coroutine)
                auto stoppedThread = target.getStoppedThread();
                REQUIRE(stoppedThread.has_value());
                CHECK(stoppedThread->id == 1);
                const std::vector<Thread>& threads = target.getThreads();
                CHECK(thread.id == 1);
                CHECK(threads.size() == 1);
                CHECK(threads.at(0) == Thread(1, "Main Coroutine"));
            }
            target.continueProcess();
            // we shouldn't get threads when things are crunning
        };
        target.launch(fixturePath, {}, config);
        auto mainThread = target.getMainThread();
        REQUIRE(mainThread.has_value());
        CHECK(mainThread->id == 1);
        CHECK(mainThread->name == "Main Coroutine");
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        // over the course of execution, the maximum number of threads encountered should be 3
        CHECK(maxThreadsSeen == 3);
        CHECK(hitsBp1 == 5);
        CHECK(hitsBp2 == 5);
    }
}
