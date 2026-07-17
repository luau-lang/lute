#pragma once

#include "lute/reporter.h"

#include <optional>
#include <string>
#include <vector>

int typecheck(const std::vector<std::string>& sourceFiles, LuteReporter& reporter, std::optional<std::string> configPath = std::nullopt);
