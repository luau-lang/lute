#pragma once

#include "lute/reporter.h"

#include <cstdio>

class TCReporter : public LuteReporter
{
public:
    void reportError(const std::string& message) override
    {
        std::fprintf(stderr, "%s\n", message.c_str());
    }

    void reportOutput(const std::string& message) override
    {
        std::fprintf(stdout, "%s\n", message.c_str());
    }
};
