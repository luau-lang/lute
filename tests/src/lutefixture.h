#pragma once

#include "testreporter.h"

#include <memory>

// Base fixture class for all Lute tests that need a reporter
class LuteFixture
{
public:
    LuteFixture();
    virtual ~LuteFixture() = default;

    TestReporter& getReporter();

    std::unique_ptr<TestReporter> reporter;
};
