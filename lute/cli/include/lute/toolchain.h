#pragma once

#include "lute/reporter.h"

#include <string>

// Return true on successful dispatch.
bool dispatchToPinnedLute(int argc, char** argv, const std::string& currentExe, LuteReporter& reporter);
