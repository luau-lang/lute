#pragma once

#include "lute/reporter.h"

#include <string>
#include <vector>

int typecheck(const std::vector<std::string>& sourceFiles, LuteReporter& reporter);
