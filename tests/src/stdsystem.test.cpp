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

TEST_CASE_FIXTURE(CliRuntimeFixture, "check_std_system_env_bools")
{
    std::string os = getHostOS();

    auto checkBool = [&](const std::string& field, bool expected) {
        runCode("local system = require(\"@std/system\")\n"
                "capture(system." + field + ")\n");
        std::string output = getCapturedOutput();
        CHECK(output == (expected ? "true" : "false"));
    };

    checkBool("win32", os == "Windows_NT");
    checkBool("linux", os == "Linux");
    checkBool("macos", os == "Darwin");
    checkBool("unix", os == "Linux" || os == "Darwin");
}