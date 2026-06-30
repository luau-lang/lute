#include "debugfixture.h"

#include "lute/runtime.h"

#include <string>

#include "luteprojectroot.h"

std::string getDebugFixturePath(const std::string& name)
{
    return getLuteProjectRootAbsolute() + "/tests/src/debug/" + name;
}

DebugFixture::DebugFixture()
    : runtime(std::make_unique<Runtime>(getReporter()))
{
    setupState(*runtime, nullptr);
}
