#include "Luau/StringUtils.h"

#include <string>

#include "cliruntimefixture.h"
#include "doctest.h"

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
        report(system.os)
    )");
    CHECK(getReporter().getOutputs()[0] == getHostOS());
}

TEST_CASE_FIXTURE(CliRuntimeFixture, "check_std_system_env_bools")
{
    std::string os = getHostOS();

    auto checkBool = [this](const std::string& field, bool expected)
    {
        std::string code = Luau::format(
            R"(
            local system = require("@std/system")
            report(system.%s))",
            field.c_str()
        );
        runCode(code);
        std::string output = this->getReporter().getOutputs()[0];
        CHECK(output == (expected ? "true" : "false"));
        this->getReporter().clear();
    };

    checkBool("win32", os == "Windows_NT");
    checkBool("linux", os == "Linux");
    checkBool("macos", os == "Darwin");
    checkBool("unix", os == "Linux" || os == "Darwin");
}
