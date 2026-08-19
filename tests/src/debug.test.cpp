#include "lute/debuginternals.h"

#include "Luau/StringUtils.h"

#include <chrono>
#include <future>
#include <optional>
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

static VariableScope checkScope(const std::vector<VariableScope>& scopes, VariableScopeType type, std::string name, int threadId, int level)
{
    auto foundScope = std::find_if(
        scopes.begin(),
        scopes.end(),
        [&](const VariableScope& scope)
        {
            return scope.name == name;
        }
    );
    REQUIRE(foundScope != scopes.end());
    CHECK(foundScope->type == type);
    CHECK(foundScope->threadId == threadId);
    CHECK(foundScope->level == level);
    CHECK(foundScope->variableReference > 0);
    return *foundScope;
}

static int checkVariable(const std::vector<Variable>& vars, const std::string& name, const std::string& value, const std::string& type, bool isTable)
{
    auto foundVar = std::find_if(
        vars.begin(),
        vars.end(),
        [&](const Variable& v)
        {
            return v.name == name;
        }
    );
    REQUIRE(foundVar != vars.end());
    CHECK(foundVar->value == value);
    CHECK(foundVar->type == type);
    if (isTable)
    {
        CHECK(foundVar->variableReference > 0);
    }
    else
    {
        CHECK(foundVar->variableReference == 0);
    }
    return foundVar->variableReference;
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

        std::optional<std::string> error = target.launch(fixturePath, {}, config);
        CHECK(!error);

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
        std::optional<std::string> error = target.launch(fixturePath, {}, config);
        CHECK(!error);

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

        std::optional<std::string> error = target.launch(fixturePath, {}, config);
        CHECK(!error);
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
        REQUIRE(target.getStoppedLocation().has_value());
        CHECK(target.getStoppedLocation() == std::make_pair(fixturePath, 2));
        // continue execution
        continuedProcess = target.continueProcess();
        REQUIRE(!target.getStoppedLocation().has_value());
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
        std::optional<std::string> error = target.launch(fixturePath, {}, config);
        CHECK(!error);
        // we hit the breakpoint and should be paused now.
        REQUIRE(hitFuture.wait_for(std::chrono::seconds(2)) == std::future_status::ready);
        std::this_thread::sleep_for(std::chrono::seconds(1));
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(0)) == std::future_status::timeout);
        CHECK(numPause == 1);
        // The pause should stop right after we finish the last line of the inner for loop.
        REQUIRE(target.getStoppedLocation().has_value());
        CHECK(target.getStoppedLocation()->second == 5);
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
        std::vector<std::string> sourceEvents;
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
        config.onSourceLoad = [&](const std::string& source) {
            sourceEvents.push_back(source);
        };
         std::optional<std::string> error = target.launch(mainPath, {}, config);
        CHECK(!error);
        // check we are done
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(bpHit1 == 5);
        CHECK(bpHit2 == 15);
        CHECK(bpInstalled == 2);
        std::vector<std::string> sources = target.getLoadedSources();
        CHECK(sources.size() == 2);
        CHECK(std::find(sources.begin(), sources.end(), mainPath) != sources.end());
        CHECK(std::find(sources.begin(), sources.end(), triangPath) != sources.end());
        CHECK(sourceEvents.size() == 2);
        CHECK(std::find(sources.begin(), sources.end(), mainPath) != sources.end());
        CHECK(std::find(sources.begin(), sources.end(), triangPath) != sources.end());
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_badlaunch")
    {
        std::string badPath = getDebugFixturePath("bad.luau");
        std::string mainPath = getDebugFixturePath("compile_error.luau");
        Target target(*runtime);
        std::optional<std::string> error = target.launch(badPath, {}, config);
        REQUIRE(error.has_value());
        CHECK(error == Luau::format("could not open file: %s", badPath.c_str()));
        error = target.launch(mainPath, {}, config);
        REQUIRE(error.has_value());
        CHECK(error == Luau::format("%s:1: Expected identifier when parsing expression, got \')\'", mainPath.c_str()));
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
        std::optional<std::string> error = target.launch(fixturePath, {}, config);
        CHECK(!error);
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(prints.size() == 2);
        CHECK(prints[0] == std::make_pair(std::string("3\tabc\tfalse\n"), 6));
        CHECK(prints[1] == std::make_pair(std::string("custom_value\n"), 7));
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_step")
    {
        std::string mainPath = getDebugFixturePath("step.luau");

        std::promise<void> hitPromise;
        std::future<void> hitFuture = hitPromise.get_future();

        std::promise<void> stepPromise;
        std::future<void> stepFuture = stepPromise.get_future();

        Target target(*runtime);
        Breakpoint bp = target.setBreakpoint(mainPath, 9);
        config.onBreakpointHit = [&](const Thread&, const Breakpoint& bp)
        {
            hitPromise.set_value();
        };
        config.onStepStop = [&](const Thread& thread, const StepInfo)
        {
            CHECK(thread.id == 1);
            stepPromise.set_value();
        };
        std::optional<std::string> error = target.launch(mainPath, {}, config);
        CHECK(!error);
        std::vector<Thread> threads = target.getThreads();
        CHECK(threads.size() == 1);
        int threadId = threads[0].id;
        // check we have hit bp
        REQUIRE(hitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        // step in acts like step over when there's no function calls
        REQUIRE(target.getStoppedLocation().has_value());
        CHECK(target.getStoppedLocation()->second == 9);
        bool stepped = target.stepIn(threadId);
        CHECK(stepped);
        REQUIRE(stepFuture.wait_for(std::chrono::seconds(1)) == std::future_status::ready);
        REQUIRE(target.getStoppedLocation().has_value());
        CHECK(target.getStoppedLocation()->second == 10);
        stepPromise = std::promise<void>{};
        stepFuture = stepPromise.get_future();
        // step into function f
        stepped = target.stepIn(threadId);
        CHECK(stepped);
        REQUIRE(stepFuture.wait_for(std::chrono::seconds(1)) == std::future_status::ready);
        REQUIRE(target.getStoppedLocation().has_value());
        CHECK(target.getStoppedLocation()->second == 2);
        stepPromise = std::promise<void>{};
        stepFuture = stepPromise.get_future();
        // this steps out of function to the next line in the caller
        stepped = target.stepOut(threadId);
        CHECK(stepped);
        REQUIRE(stepFuture.wait_for(std::chrono::seconds(1)) == std::future_status::ready);
        REQUIRE(target.getStoppedLocation().has_value());
        CHECK(target.getStoppedLocation()->second == 11);
        stepPromise = std::promise<void>{};
        stepFuture = stepPromise.get_future();
        // this steps over a function
        stepped = target.stepOver(threadId);
        CHECK(stepped);
        REQUIRE(stepFuture.wait_for(std::chrono::seconds(1)) == std::future_status::ready);
        REQUIRE(target.getStoppedLocation().has_value());
        CHECK(target.getStoppedLocation()->second == 12);
        stepPromise = std::promise<void>{};
        stepFuture = stepPromise.get_future();
        // this steps to the virtual last line
        stepped = target.stepOver(threadId);
        CHECK(stepped);
        REQUIRE(stepFuture.wait_for(std::chrono::seconds(1)) == std::future_status::ready);
        REQUIRE(target.getStoppedLocation().has_value());
        CHECK(target.getStoppedLocation()->second == 13);
        target.stepOver(threadId);

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
        int hitsBp1 = 0;
        int hitsBp2 = 0;
        int total_sum_val = 0;
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
                std::optional<std::vector<StackFrame>> stackTrace = target.getStackTrace(thread.id);
                REQUIRE(stackTrace.has_value());
                StackFrame threadStack = stackTrace->at(stackTrace->size() - 1);
                CHECK(threadStack.line == 7);
                std::optional<std::vector<Variable>> vars = target.getVariablesByScopeType(threadStack.id, VariableScopeType::Local);
                REQUIRE(vars.has_value());
                checkVariable(*vars, "_i", std::to_string(hitsBp1), "number", false);
                std::optional<std::vector<Variable>> upvalues = target.getVariablesByScopeType(threadStack.id, VariableScopeType::Upvalue);
                REQUIRE(upvalues.has_value());
                checkVariable(*upvalues, "total_sum", std::to_string(total_sum_val), "number", false);
                total_sum_val++;
                for (const Thread& thread : threads)
                {
                    if (thread.id == 3)
                    {
                        std::optional<std::vector<StackFrame>> stackTrace = target.getStackTrace(thread.id);
                        REQUIRE(stackTrace.has_value());
                        if (stackTrace->size() > 0)
                        {
                            int line = stackTrace->at(stackTrace->size() - 1).line;
                            CHECK((line >= 12 && line <= 16));
                        }
                    }
                    if (thread.id == 1)
                    {
                        std::optional<std::vector<StackFrame>> stackTrace = target.getStackTrace(thread.id);
                        REQUIRE(stackTrace.has_value());
                        if (stackTrace->size() > 0)
                        {
                            int line = stackTrace->at(stackTrace->size() - 1).line;
                            CHECK((line >= 18 && line <= 20));
                        }
                    }
                }
            }
            else if (bp.id == bp2.id)
            {
                CHECK(thread.id == 3);
                auto stoppedThread = target.getStoppedThread();
                REQUIRE(stoppedThread.has_value());
                CHECK(stoppedThread->id == 3);
                std::optional<std::vector<StackFrame>> stackTrace = target.getStackTrace(thread.id);
                REQUIRE(stackTrace.has_value());
                StackFrame threadStack = stackTrace->at(stackTrace->size() - 1);
                CHECK(threadStack.line == 14);
                const std::vector<Thread>& threads = target.getThreads();
                for (const Thread& thread : threads)
                {
                    if (thread.id == 2)
                    {
                        std::optional<std::vector<StackFrame>> stackTrace = target.getStackTrace(thread.id);
                        REQUIRE(stackTrace.has_value());
                        if (stackTrace->size() > 0)
                        {
                            int line = stackTrace->at(stackTrace->size() - 1).line;
                            CHECK((line >= 5 && line <= 9));
                        }
                    }
                    if (thread.id == 1)
                    {
                        std::optional<std::vector<StackFrame>> stackTrace = target.getStackTrace(thread.id);
                        REQUIRE(stackTrace.has_value());
                        if (stackTrace->size() > 0)
                        {
                            int line = stackTrace->at(stackTrace->size() - 1).line;
                            CHECK((line >= 18 && line <= 20));
                        }
                    }
                }
                hitsBp2++;
                std::optional<std::vector<Variable>> vars = target.getVariablesByScopeType(threadStack.id, VariableScopeType::Local);
                REQUIRE(vars.has_value());
                checkVariable(*vars, "_i", std::to_string(hitsBp2), "number", false);
                std::optional<std::vector<Variable>> upvalues = target.getVariablesByScopeType(threadStack.id, VariableScopeType::Upvalue);
                REQUIRE(upvalues.has_value());
                checkVariable(*upvalues, "total_sum", std::to_string(total_sum_val), "number", false);
                total_sum_val++;
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
        CHECK(total_sum_val == 10);
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_stackFrame")
    {
        std::string fixturePath = getDebugFixturePath("recursion.luau");
        Target target(*runtime);
        Breakpoint bpA = target.setBreakpoint(fixturePath, 4);
        Breakpoint bpB = target.setBreakpoint(fixturePath, 8);
        Breakpoint mainBp = target.setBreakpoint(fixturePath, 14);
        int hits = 0;
        config.onBreakpointHit = [&](const Thread&, const Breakpoint& bp)
        {
            const std::vector<Thread>& threads = target.getThreads();
            CHECK(threads.size() == 1);
            int threadId = threads.at(0).id;
            std::optional<std::vector<StackFrame>> stacktrace = target.getStackTrace(threadId);
            REQUIRE(stacktrace.has_value());
            // our stack trace should from the most deep stack frame go main -> a -> b -> a -> b ....
            // the stack trace returns this in reverse since it starts from the shallowest stack frame.
            hits++;
            bool hitA = false;
            int expectedTraceSize = hits;
            if (bp.id == bpA.id)
            {
                hitA = true;
            }
            CHECK(stacktrace->size() == expectedTraceSize);
            CHECK(target.getStackDepth(threadId) == expectedTraceSize);
            for (int i = 0; i < expectedTraceSize; i++)
            {
                int line;
                int column = 0;
                std::string name;
                std::string sourcePath = fixturePath;
                if (i == expectedTraceSize - 1)
                {
                    line = 14;
                    name = "(entry)";
                }
                else if ((hitA && i % 2 == 0) || (!hitA && i % 2 == 1))
                {
                    line = 4;
                    name = "a";
                }
                else
                {
                    // the function name field is not set during the equality operation
                    // so B stays anonymous
                    name = "(anonymous)";
                    if (!hitA && i == 0)
                    {
                        line = 8;
                    }
                    else
                    {
                        line = 11;
                    }
                }
                StackFrame frame = stacktrace->at(i);
                CHECK(frame.id == i + 1);
                CHECK(frame.column == column);
                CHECK(frame.line == line);
                CHECK(frame.name == name);
                CHECK(frame.sourcePath == sourcePath);
            }
            bool continued = target.continueProcess();
            CHECK(continued);
            stacktrace = target.getStackTrace(threadId);
            // we shouldn't get stack trace when things are paused
            REQUIRE(!stacktrace.has_value());
        };
        target.launch(fixturePath, {}, config);
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(hits == 9);
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_variables")
    {
        std::string fixturePath = getDebugFixturePath("variables.luau");
        Target target(*runtime);
        target.setBreakpoint(fixturePath, 16);
        config.onBreakpointHit = [&](const Thread&, const Breakpoint&)
        {
            const std::vector<Thread>& threads = target.getThreads();
            REQUIRE(threads.size() == 1);
            std::optional<std::vector<StackFrame>> stackframe = target.getStackTrace(threads.at(0).id);
            REQUIRE(stackframe.has_value());
            // stack frame at level 0
            std::optional<std::vector<VariableScope>> scopes = target.getScopes(stackframe->at(0).id);
            REQUIRE(scopes.has_value());
            checkScope(*scopes, VariableScopeType::Local, "Locals", 1, 0);
            checkScope(*scopes, VariableScopeType::Upvalue, "Upvalues", 1, 0);
            checkScope(*scopes, VariableScopeType::Global, "Globals", 1, 0);
            std::optional<std::vector<Variable>> upvalues0 = target.getVariablesByScopeType(stackframe->at(0).id, VariableScopeType::Upvalue);
            REQUIRE(upvalues0.has_value());
            checkVariable(*upvalues0, "a", "24", "number", false);
            checkVariable(*upvalues0, "_b", "1.2", "number", false);
            std::optional<std::vector<Variable>> locals0 = target.getVariablesByScopeType(stackframe->at(0).id, VariableScopeType::Local);
            checkVariable(*locals0, "_k", "25.2", "number", false);
            std::optional<std::vector<Variable>> globals = target.getVariablesByScopeType(stackframe->at(0).id, VariableScopeType::Global);
            REQUIRE(globals.has_value());
            checkVariable(*globals, "_global_var", "16", "number", false);
            // stack frame at level 1
            scopes = target.getScopes(stackframe->at(1).id);
            REQUIRE(scopes.has_value());
            checkScope(*scopes, VariableScopeType::Local, "Locals", 1, 1);
            checkScope(*scopes, VariableScopeType::Upvalue, "Upvalues", 1, 1);
            checkScope(*scopes, VariableScopeType::Global, "Globals", 1, 1);
            std::optional<std::vector<Variable>> locals1 = target.getVariablesByScopeType(stackframe->at(1).id, VariableScopeType::Local);
            REQUIRE(locals1.has_value());
            checkVariable(*locals1, "a", "24", "number", false);
            checkVariable(*locals1, "_b", "1.2", "number", false);
            checkVariable(*locals1, "_c", "\"test\"", "string", false);
            int ref1 = checkVariable(*locals1, "_d", "{1, 2, 3}", "table", true);
            int ref2 = checkVariable(*locals1, "_e", "{a=4, [4]={r=13}, b=\"5\"}", "table", true);
            checkVariable(*locals1, "_f", "true", "boolean", false);
            checkVariable(*locals1, "g", "function", "function", false);
            checkVariable(*locals1, "_largeinteger", "123456789101112", "number", false);
            checkVariable(*locals1, "_smallnumber", "1.2e-14", "number", false);
            checkVariable(*locals1, "_largenumber", "3.53e+106", "number", false);
            checkVariable(*locals1, "_escapechar", "\"\\n\\\\\\r\\t\\\"\"", "string", false);
            checkVariable(*locals1, "_precise", "1.234567891011", "number", false);
            std::optional<std::vector<Variable>> table = target.getVariables(ref1);
            REQUIRE(table.has_value());
            checkVariable(*table, "[1]", "1", "number", false);
            checkVariable(*table, "[2]", "2", "number", false);
            checkVariable(*table, "[3]", "3", "number", false);
            table = target.getVariables(ref2);
            REQUIRE(table.has_value());
            checkVariable(*table, "a", "4", "number", false);
            int ref3 = checkVariable(*table, "[4]", "{r=13}", "table", true);
            checkVariable(*table, "b", "\"5\"", "string", false);
            table = target.getVariables(ref3);
            REQUIRE(table.has_value());
            checkVariable(*table, "r", "13", "number", false);
            std::optional<std::vector<Variable>> upvalues1 = target.getVariablesByScopeType(stackframe->at(1).id, VariableScopeType::Upvalue);
            REQUIRE(upvalues1.has_value());
            CHECK(upvalues1->size() == 0);
            globals = target.getVariablesByScopeType(stackframe->at(1).id, VariableScopeType::Global);
            REQUIRE(globals.has_value());
            checkVariable(*globals, "_global_var", "16", "number", false);
            target.continueProcess();
        };
        target.launch(fixturePath, {}, config);
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
    };

    TEST_CASE_FIXTURE(DebugFixture, "Debug_evalExpression")
    {
        std::string fixturePath = getDebugFixturePath("variables.luau");
        Target target(*runtime);
        target.setBreakpoint(fixturePath, 16);

        std::vector<Variable> capturedLocals;
        config.onBreakpointHit = [&](const Thread&, const Breakpoint&)
        {
            const std::vector<Thread>& threads = target.getThreads();
            REQUIRE(threads.size() == 1);
            std::optional<std::vector<StackFrame>> stackframe = target.getStackTrace(threads.at(0).id);
            REQUIRE(stackframe.has_value());
            EvaluateResult result = target.evaluateExpression("2", stackframe->at(0).id);
            REQUIRE(std::holds_alternative<Variable>(result));
            Variable var = std::get<Variable>(result);
            CHECK(var.value == "2");
            CHECK(var.type == "number");
            result = target.evaluateExpression("2 * a", stackframe->at(0).id);
            REQUIRE(std::holds_alternative<Variable>(result));
            var = std::get<Variable>(result);
            CHECK(var.value == "48");
            CHECK(var.type == "number");
            result = target.evaluateExpression("_d[3]", stackframe->at(1).id);
            REQUIRE(std::holds_alternative<Variable>(result));
            var = std::get<Variable>(result);
            CHECK(var.value == "3");
            CHECK(var.type == "number");
            result = target.evaluateExpression("_e.b", stackframe->at(1).id);
            REQUIRE(std::holds_alternative<Variable>(result));
            var = std::get<Variable>(result);
            CHECK(var.value == "\"5\"");
            CHECK(var.type == "string");
            result = target.evaluateExpression("g()", stackframe->at(1).id);
            REQUIRE(std::holds_alternative<Variable>(result));
            var = std::get<Variable>(result);
            CHECK(var.value == "25.2");
            CHECK(var.type == "number");
            result = target.evaluateExpression("_e[4]", stackframe->at(1).id);
            REQUIRE(std::holds_alternative<Variable>(result));
            var = std::get<Variable>(result);
            CHECK(var.value == "{r=13}");
            CHECK(var.type == "table");
            CHECK(var.variableReference > 0);
            result = target.evaluateExpression("x + ", stackframe->at(0).id);
            REQUIRE(std::holds_alternative<std::string>(result));
            std::string errorMessage = std::get<std::string>(result);
            CHECK(errorMessage == "eval:1: Expected identifier when parsing expression, got <eof>");
            result = target.evaluateExpression("_e.bad + 1", stackframe->at(1).id);
            REQUIRE(std::holds_alternative<std::string>(result));
            errorMessage = std::get<std::string>(result);
            CHECK(errorMessage == "eval:1: attempt to perform arithmetic (add) on nil and number");
            result = target.evaluateExpression("_k", stackframe->at(1).id);
            REQUIRE(std::holds_alternative<Variable>(result));
            var = std::get<Variable>(result);
            CHECK(var.value == "nil");
            CHECK(var.type == "nil");
            result = target.evaluateExpression("tostring(42)", -1);
            REQUIRE(std::holds_alternative<Variable>(result));
            var = std::get<Variable>(result);
            CHECK(var.value == "\"42\"");
            CHECK(var.type == "string");
            result = target.evaluateExpression("_global_var", stackframe->at(0).id);
            REQUIRE(std::holds_alternative<Variable>(result));
            var = std::get<Variable>(result);
            CHECK(var.value == "16");
            CHECK(var.type == "number");
            target.continueProcess();
        };
        target.launch(fixturePath, {}, config);
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
    };

    TEST_CASE_FIXTURE(DebugFixture, "Debug_xpcall")
    {
        std::string fixturePath = getDebugFixturePath("xpcall.luau");
        Target target(*runtime);
        Breakpoint bpErrorHandler = target.setBreakpoint(fixturePath, 4);
        Breakpoint bpOutside = target.setBreakpoint(fixturePath, 7);
        int numHits = 0;
        config.onBreakpointHit = [&](const Thread&, const Breakpoint& bp)
        {
            const std::vector<Thread>& threads = target.getThreads();
            REQUIRE(threads.size() == 1);
            const std::optional<std::vector<StackFrame>> st = target.getStackTrace(threads[0].id);
            REQUIRE(st.has_value());
            if (bp.id == bpErrorHandler.id)
            {
                std::optional<std::vector<Variable>> locals = target.getVariablesByScopeType(st->at(0).id, VariableScopeType::Local);
                REQUIRE(locals.has_value());
                std::string errorValue = "\"" + Luau::format("%s:2: attempt to call a nil value", fixturePath.c_str()) + "\"";
                checkVariable(*locals, "_err", errorValue, "string", false);
                numHits++;
            }
            if (bp.id == bpOutside.id)
            {
                std::optional<std::vector<Variable>> locals = target.getVariablesByScopeType(st->at(0).id, VariableScopeType::Local);
                REQUIRE(locals.has_value());
                checkVariable(*locals, "returned", "false", "boolean", false);
                checkVariable(*locals, "_data", "\"error found\"", "string", false);
                numHits++;
            }
            target.continueProcess();
        };
        target.launch(fixturePath, {}, config);
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(numHits == 2);
    };

    TEST_CASE_FIXTURE(DebugFixture, "Debug_metatable")
    {
        std::string fixturePath = getDebugFixturePath("metatable.luau");
        Target target(*runtime);
        Breakpoint bpIndex = target.setBreakpoint(fixturePath, 4);
        Breakpoint bpCall = target.setBreakpoint(fixturePath, 7);
        int numHits = 0;
        config.onBreakpointHit = [&](const Thread&, const Breakpoint& bp)
        {
            const std::vector<Thread>& threads = target.getThreads();
            REQUIRE(threads.size() == 1);
            const std::optional<std::vector<StackFrame>> st = target.getStackTrace(threads[0].id);
            REQUIRE(st.has_value());
            if (bp.id == bpIndex.id)
            {
                std::optional<std::vector<Variable>> locals = target.getVariablesByScopeType(st->at(0).id, VariableScopeType::Local);
                REQUIRE(locals.has_value());
                checkVariable(*locals, "k", "7", "number", false);
                numHits++;
            }
            if (bp.id == bpCall.id)
            {
                std::optional<std::vector<Variable>> locals = target.getVariablesByScopeType(st->at(0).id, VariableScopeType::Local);
                REQUIRE(locals.has_value());
                checkVariable(*locals, "k", "5", "number", false);
                numHits++;
            }
            target.continueProcess();
        };
        target.launch(fixturePath, {}, config);
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(numHits == 2);
    };

    TEST_CASE_FIXTURE(DebugFixture, "Debug_globalscoping")
    {
        std::string fixturePath = getDebugFixturePath("global_scope.luau");
        std::string importPath = getDebugFixturePath("global_import.luau");

        Target target(*runtime);
        Breakpoint bp1 = target.setBreakpoint(fixturePath, 5);
        Breakpoint bp2 = target.setBreakpoint(importPath, 6);
        int numHits = 0;
        config.onBreakpointHit = [&](const Thread&, const Breakpoint& bp)
        {
            const std::vector<Thread>& threads = target.getThreads();
            REQUIRE(threads.size() == 1);
            const std::optional<std::vector<StackFrame>> st = target.getStackTrace(threads[0].id);
            REQUIRE(st.has_value());
            if (bp.id == bp1.id)
            {
                std::optional<std::vector<Variable>> globals = target.getVariablesByScopeType(st->at(0).id, VariableScopeType::Global);
                REQUIRE(globals.has_value());
                checkVariable(*globals, "_global_var", "3", "number", false);
                checkVariable(*globals, "_global_var2", "5", "number", false);
                REQUIRE(globals->size() == 2);
                EvaluateResult result = target.evaluateExpression("_global_var * 5", st->at(0).id);
                REQUIRE(std::holds_alternative<Variable>(result));
                Variable var = std::get<Variable>(result);
                CHECK(var.value == "15");
                CHECK(var.type == "number");
                numHits++;
            }
            if (bp.id == bp2.id)
            {
                std::optional<std::vector<Variable>> globals = target.getVariablesByScopeType(st->at(0).id, VariableScopeType::Global);
                REQUIRE(globals.has_value());
                checkVariable(*globals, "_global_var", "6", "number", false);
                REQUIRE(globals->size() == 1);
                EvaluateResult result = target.evaluateExpression("_global_var * 5", st->at(0).id);
                REQUIRE(std::holds_alternative<Variable>(result));
                Variable var = std::get<Variable>(result);
                CHECK(var.value == "30");
                CHECK(var.type == "number");
                numHits++;
            }
            target.continueProcess();
        };
        target.launch(fixturePath, {}, config);
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(numHits == 2);
    };

    TEST_CASE_FIXTURE(DebugFixture, "Debug_sourceBreakpoints")
    {
        std::string fixturePath = getDebugFixturePath("loop.luau");
        Target target(*runtime);
        BreakpointConfig conditional = {"_step2 > 6"};
        BreakpointConfig hitCondition;
        hitCondition.hitCondition = " % 5";
        BreakpointConfig log;
        log.logMessage = "} my value is {_step2 * 3} and {_step1 + 5}";
        Breakpoint normalBp = target.setBreakpoint(fixturePath, 6);
        Breakpoint conditionalBp = target.setBreakpoint(fixturePath, 7, conditional);
        Breakpoint hitConditionBp = target.setBreakpoint(fixturePath, 8, hitCondition);
        Breakpoint logpoints = target.setBreakpoint(fixturePath, 4, log);
        std::vector<std::string> logs;
        config.onLogpointHit = [&](std::string message, const Breakpoint& bpHit)
        {
            logs.push_back(message);
            CHECK(bpHit.sourcePath == fixturePath);
            CHECK(bpHit.line == 4);
        };
        int hits = 0, conditionalStops = 0, hitConditionStops = 0;
        config.onBreakpointHit = [&](const Thread&, const Breakpoint& bpHit)
        {
            if (bpHit.id == normalBp.id)
            {
                hits++;
            }
            else if (bpHit.id == conditionalBp.id)
            {
                conditionalStops++;
                CHECK(hits >= 3);
                CHECK(conditionalStops == hits - 3);
            }
            else if (bpHit.id == hitConditionBp.id)
            {
                hitConditionStops++;
                CHECK(hits % 5 == 0);
            }
            target.continueProcess();
        };
        target.launch(fixturePath, {}, config);
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(hits == 25);
        CHECK(conditionalStops == 22);
        CHECK(hitConditionStops == 5);
        CHECK(logs.size() == 5);
        for (int i = 0; i < (int)(logs.size()); i++)
        {
            std::string expected = Luau::format("} my value is %d and %d\n", 30 * i, 6 * i + 5);
            CHECK(logs[i] == expected);
        }
    };

    TEST_CASE_FIXTURE(DebugFixture, "Debug_exception")
    {
        std::string mainPath = getDebugFixturePath("exception.luau");
        Target target(*runtime);
        ExceptionBreakpointInfo info = target.setExceptionBreakpoint(true, true);
        int hits = 0;
        config.onException = [&](const Thread& thread, int bpId, const std::string& message)
        {
            if (bpId == info.caughtId)
            {
                hits++;
                CHECK(message == Luau::format("%s:3: attempt to index nil with \'foo\'", mainPath.c_str()));
                CHECK(thread.id == 1);
                target.continueProcess();
            }
            else
            {
                hits++;
                CHECK(message == Luau::format("%s:7: attempt to index nil with \'foo\'", mainPath.c_str()));
                CHECK(thread.id == 1);
                target.continueProcess();
            }
        };
        std::optional<std::string> error = target.launch(mainPath, {}, config);
        CHECK(!error);
        // check we are done
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(hits == 2);
    }

    // This test is specifically designed to make sure the error handler still runs after finishing with a caught exception.
    TEST_CASE_FIXTURE(DebugFixture, "Debug_exception_xpcall")
    {
        std::string mainPath = getDebugFixturePath("xpcall.luau");
        Target target(*runtime);
        ExceptionBreakpointInfo info = target.setExceptionBreakpoint(true, true);
        target.setBreakpoint(mainPath, 7);
        int hits = 0;
        config.onException = [&](const Thread& thread, int bpId, const std::string& message)
        {
            if (bpId == info.caughtId)
            {
                hits++;
                CHECK(message == Luau::format("%s:2: attempt to call a nil value", mainPath.c_str()));
                CHECK(thread.id == 1);
                target.continueProcess();
            }
        };
        config.onBreakpointHit = [&](const Thread& thread, const Breakpoint&)
        {
            const std::vector<Thread>& threads = target.getThreads();
            REQUIRE(threads.size() == 1);
            std::optional<std::vector<StackFrame>> stackframe = target.getStackTrace(threads.at(0).id);
            REQUIRE(stackframe.has_value());
            EvaluateResult result = target.evaluateExpression("returned", stackframe->at(0).id);
            REQUIRE(std::holds_alternative<Variable>(result));
            Variable var = std::get<Variable>(result);
            CHECK(var.value == "false");
            CHECK(var.type == "boolean");
            result = target.evaluateExpression("_data", stackframe->at(0).id);
            REQUIRE(std::holds_alternative<Variable>(result));
            var = std::get<Variable>(result);
            CHECK(var.value == "\"error found\"");
            CHECK(var.type == "string");
            target.continueProcess();
        };
        std::optional<std::string> error = target.launch(mainPath, {}, config);
        CHECK(!error);
        // check we are done
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
        CHECK(hits == 1);
    }

    TEST_CASE_FIXTURE(DebugFixture, "Debug_setVariable")
    {
        std::string fixturePath = getDebugFixturePath("variables.luau");
        Target target(*runtime);
        Breakpoint bp1 = target.setBreakpoint(fixturePath, 7);
        Breakpoint bp2 = target.setBreakpoint(fixturePath, 15);
        Breakpoint bp3 = target.setBreakpoint(fixturePath, 16);
        config.onBreakpointHit = [&](const Thread&, const Breakpoint& bp)
        {
            const std::vector<Thread>& threads = target.getThreads();
            REQUIRE(threads.size() == 1);
            std::optional<std::vector<StackFrame>> stackframe = target.getStackTrace(threads.at(0).id);
            REQUIRE(stackframe.has_value());
            // stack frame at level 0
            std::optional<std::vector<VariableScope>> scopes = target.getScopes(stackframe->at(0).id);
            REQUIRE(scopes.has_value());
            VariableScope locals = checkScope(*scopes, VariableScopeType::Local, "Locals", 1, 0);
            VariableScope upvalues = checkScope(*scopes, VariableScopeType::Upvalue, "Upvalues", 1, 0);
            if (bp.id == bp1.id)
            {
                EvaluateResult result = target.setVariable(locals.variableReference, "a", "35 - 13");
                REQUIRE(std::holds_alternative<Variable>(result));
                Variable var = std::get<Variable>(result);
                CHECK(var.value == "22");
                std::optional<std::vector<Variable>> locals0 = target.getVariablesByScopeType(stackframe->at(0).id, VariableScopeType::Local);
                REQUIRE(locals0.has_value());
                int tableRef = checkVariable(*locals0, "_e", "{a=4, [4]={r=13}, b=\"5\"}", "table", true);
                result = target.setVariable(tableRef, "b", "1 - 13");
                REQUIRE(std::holds_alternative<Variable>(result));
                var = std::get<Variable>(result);
                CHECK(var.value == "-12");
            }
            if (bp.id == bp2.id)
            {
                std::optional<std::vector<Variable>> upvalues0 = target.getVariablesByScopeType(stackframe->at(0).id, VariableScopeType::Upvalue);
                REQUIRE(upvalues0.has_value());
                checkVariable(*upvalues0, "a", "44", "number", false);
                EvaluateResult result = target.setVariable(upvalues.variableReference, "_b", "3 + 1.3");
                REQUIRE(std::holds_alternative<Variable>(result));
                Variable var = std::get<Variable>(result);
                CHECK(var.value == "4.3");
                std::optional<std::vector<Variable>> locals1 = target.getVariablesByScopeType(stackframe->at(1).id, VariableScopeType::Local);
                REQUIRE(locals1.has_value());
                int tableRef = checkVariable(*locals1, "_e", "{a=4, [4]={r=13}, b=-12}", "table", true);
                std::optional<std::vector<Variable>> table = target.getVariables(tableRef);
                REQUIRE(table.has_value());
                checkVariable(*table, "b", "-12", "number", false);
            }
            if (bp.id == bp3.id)
            {
                std::optional<std::vector<Variable>> upvalues0 = target.getVariablesByScopeType(stackframe->at(0).id, VariableScopeType::Upvalue);
                REQUIRE(upvalues0.has_value());
                checkVariable(*upvalues0, "_b", "4.3", "number", false);
                std::optional<std::vector<Variable>> locals0 = target.getVariablesByScopeType(stackframe->at(0).id, VariableScopeType::Local);
                REQUIRE(locals0.has_value());
                checkVariable(*locals0, "_k", "48.3", "number", false);
            }
            target.continueProcess();
        };
        target.launch(fixturePath, {}, config);
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
    };

    TEST_CASE_FIXTURE(DebugFixture, "Debug_setExpression")
    {
        std::string fixturePath = getDebugFixturePath("variables.luau");
        Target target(*runtime);
        Breakpoint bp1 = target.setBreakpoint(fixturePath, 7);
        Breakpoint bp2 = target.setBreakpoint(fixturePath, 15);
        Breakpoint bp3 = target.setBreakpoint(fixturePath, 16);
        config.onBreakpointHit = [&](const Thread&, const Breakpoint& bp)
        {
            const std::vector<Thread>& threads = target.getThreads();
            REQUIRE(threads.size() == 1);
            std::optional<std::vector<StackFrame>> stackframe = target.getStackTrace(threads.at(0).id);
            REQUIRE(stackframe.has_value());
            if (bp.id == bp1.id)
            {
                EvaluateResult result = target.setExpression("a", "35 - 13", stackframe->at(0).id);
                REQUIRE(std::holds_alternative<Variable>(result));
                Variable var = std::get<Variable>(result);
                CHECK(var.value == "22");
                result = target.setExpression("_e.b", "1 - 13", stackframe->at(0).id);
                REQUIRE(std::holds_alternative<Variable>(result));
                var = std::get<Variable>(result);
                CHECK(var.value == "-12");
            }
            if (bp.id == bp2.id)
            {
                std::optional<std::vector<Variable>> upvalues0 = target.getVariablesByScopeType(stackframe->at(0).id, VariableScopeType::Upvalue);
                REQUIRE(upvalues0.has_value());
                checkVariable(*upvalues0, "a", "44", "number", false);
                EvaluateResult result = target.setExpression("_b", "3 + 1.3", stackframe->at(0).id);
                Variable var = std::get<Variable>(result);
                CHECK(var.value == "4.3");
                std::optional<std::vector<Variable>> locals1 = target.getVariablesByScopeType(stackframe->at(1).id, VariableScopeType::Local);
                REQUIRE(locals1.has_value());
                int tableRef = checkVariable(*locals1, "_e", "{a=4, [4]={r=13}, b=-12}", "table", true);
                std::optional<std::vector<Variable>> table = target.getVariables(tableRef);
                REQUIRE(table.has_value());
                checkVariable(*table, "b", "-12", "number", false);
            }
            if (bp.id == bp3.id)
            {
                std::optional<std::vector<Variable>> upvalues0 = target.getVariablesByScopeType(stackframe->at(0).id, VariableScopeType::Upvalue);
                REQUIRE(upvalues0.has_value());
                checkVariable(*upvalues0, "_b", "4.3", "number", false);
                std::optional<std::vector<Variable>> locals0 = target.getVariablesByScopeType(stackframe->at(0).id, VariableScopeType::Local);
                REQUIRE(locals0.has_value());
                checkVariable(*locals0, "_k", "48.3", "number", false);
            }
            target.continueProcess();
        };
        target.launch(fixturePath, {}, config);
        REQUIRE(exitFuture.wait_for(std::chrono::seconds(5)) == std::future_status::ready);
    };
}
