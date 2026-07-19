#pragma once

#include "lute/reporter.h"

#include <string>

// Attempts to re-exec into a project-pinned lute binary.
// Returns -1 if no dispatch occurred (caller should proceed normally).
// Returns 1 on error. Does not return on successful dispatch (execv).
int dispatchToPinnedLute(int argc, char** argv, const std::string& currentExe, LuteReporter& reporter);
