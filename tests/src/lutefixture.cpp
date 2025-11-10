#include "lutefixture.h"

LuteFixture::LuteFixture()
    : reporter(std::make_unique<TestReporter>())
{
}

TestReporter& LuteFixture::getReporter()
{
    return *reporter;
}
