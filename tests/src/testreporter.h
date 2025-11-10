#pragma once

#include "lute/reporter.h"
#include <string>
#include <vector>

// Test reporter that captures output in vectors for verification
class TestReporter : public LuteReporter
{
public:
    void reportError(const std::string& message) override;
    void reportOutput(const std::string& message) override;

    const std::vector<std::string>& getErrors() const;
    const std::vector<std::string>& getOutputs() const;

    void clear();

private:
    std::vector<std::string> errors;
    std::vector<std::string> outputs;
};
