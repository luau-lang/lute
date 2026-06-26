#pragma once

#include "lute/runtime.h"

#include <memory>
#include <string>

#include "debugger.h"
#include "lutefixture.h"

class DebugFixture : public LuteFixture
{
public:
    DebugFixture();
    ~DebugFixture();

    std::string writeScript(const std::string& source);

    std::string scriptPath;
    std::unique_ptr<Runtime> runtime;
};
