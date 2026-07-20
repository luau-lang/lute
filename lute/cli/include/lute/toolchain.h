#pragma once

#include "lute/reporter.h"

// Re-execs into the project-pinned lute when one is configured. Returns false on failure.
bool dispatchToPinnedLute(int argc, char** argv, LuteReporter& reporter);
