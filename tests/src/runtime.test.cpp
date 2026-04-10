#include "cliruntimefixture.h"
#include "doctest.h"

TEST_CASE_FIXTURE(CliRuntimeFixture, "runtime_will_not_resume_cancelled_task_spawn")
{
    runCode(R"(
        local task = require("@std/task")
        local t = task.spawn(function()
            task.wait(2)
        end)

        task.cancel(t)
    )");

    auto reporter = getReporter();
    for (auto s : reporter.getErrors())
    {
        auto idx = s.find("cannot resume dead coroutine");
        CHECK(idx == std::string::npos);
    }
}
