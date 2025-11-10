#include "testreporter.h"

void TestReporter::reportError(const std::string& message)
{
    errors.push_back(message);
}

void TestReporter::reportOutput(const std::string& message)
{
    outputs.push_back(message);
}

const std::vector<std::string>& TestReporter::getErrors() const
{
    return errors;
}

const std::vector<std::string>& TestReporter::getOutputs() const
{
    return outputs;
}

void TestReporter::clear()
{
    errors.clear();
    outputs.clear();
}
