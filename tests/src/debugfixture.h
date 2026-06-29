#pragma once

#include "lute/runtime.h"

#include <string>

#include "debugger.h"
#include "lutefixture.h"

std::string getDebugFixturePath(const std::string& name);

class DebugFixture : public LuteFixture
{
public:
    DebugFixture();
    std::unique_ptr<Runtime> runtime;
};
