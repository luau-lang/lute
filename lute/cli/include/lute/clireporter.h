#pragma once

#include "lute/reporter.h"

// Standard CLI reporter that writes to stderr and stdout
class CLIReporter : public LuteReporter
{
public:
    void reportError(const std::string& message) override;
    void reportOutput(const std::string& message) override;
};
