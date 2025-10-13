#include "doctest.h"

#include "cliruntimefixture.h"

#include <string>

std::string getHostOS()
{
#if defined(__linux__)
    return "Linux";
#elif defined(__APPLE__)
    return "Darwin";
#elif defined(_WIN32)
    return "Windows_NT";
#else
    return "unknown";
#endif
}

TEST_CASE_FIXTURE(CliRuntimeFixture, "std_system_os_matches_host_os")
{
    runCode(R"(
        local system = require("@std/system")
        capture(system.os)
    )");
    CHECK(getCapturedOutput() == getHostOS());
}