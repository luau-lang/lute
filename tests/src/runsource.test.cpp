#include "cliruntimefixture.h"
#include "doctest.h"

TEST_CASE_FIXTURE(CliRuntimeFixture, "Runtime_runSource_executes_source")
{
    bool result = runCode(R"(
        report("hello from runSource")
    )");

    CHECK(result == true);
    REQUIRE(getReporter().getOutputs().size() == 1);
    CHECK(getReporter().getOutputs()[0] == "hello from runSource");
}

TEST_CASE_FIXTURE(CliRuntimeFixture, "Runtime_runSource_multiple_outputs")
{
    bool result = runCode(R"(
        report("first")
        report("second")
        report("third")
    )");

    CHECK(result == true);
    REQUIRE(getReporter().getOutputs().size() == 3);
    CHECK(getReporter().getOutputs()[0] == "first");
    CHECK(getReporter().getOutputs()[1] == "second");
    CHECK(getReporter().getOutputs()[2] == "third");
}

TEST_CASE_FIXTURE(CliRuntimeFixture, "Runtime_runSource_computation")
{
    bool result = runCode(R"(
        local sum = 0
        for i = 1, 10 do
            sum += i
        end
        report(tostring(sum))
    )");

    CHECK(result == true);
    REQUIRE(getReporter().getOutputs().size() == 1);
    CHECK(getReporter().getOutputs()[0] == "55");
}

TEST_CASE_FIXTURE(CliRuntimeFixture, "Runtime_runSource_error")
{
    bool result = runCode(R"(
        error("fail")
    )");

    CHECK(result == false);
}
