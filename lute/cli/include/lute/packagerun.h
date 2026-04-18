#pragma once

#include "lute/userlandvfs.h"

#include <optional>
#include <string>
#include <utility>
#include <vector>

std::optional<std::string> getAbsolutePathToNearestLockfile(std::string entryFile);

std::pair<std::vector<Package::Identifier>, std::vector<std::pair<Package::Identifier, Package::Info>>> getDependenciesFromLockfile(
    const std::string& lockfilePath,
    const std::string& entryFilePath
);
