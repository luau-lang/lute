#include "lute/clireporter.h"

#include <cstdio>

void CLIReporter::reportError(const std::string& message)
{
    fprintf(stderr, "%s\n", message.c_str());
}

void CLIReporter::reportOutput(const std::string& message)
{
    fprintf(stdout, "%s\n", message.c_str());
}
