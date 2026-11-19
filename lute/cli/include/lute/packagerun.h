#pragma once

#include "lute/result.h"
#include "lute/userlandvfs.h"

#include <optional>
#include <string>
#include <utility>
#include <vector>

std::optional<std::string> getAbsolutePathToNearestLockfile(std::string entryFile);

struct LockfileDependencies
{
    std::vector<Package::Identifier> directDependencies;
    std::vector<std::pair<Package::Identifier, Package::Info>> allDependencies;
};

// Fails with a diagnostic if the lockfile cannot be read or is malformed.
Lute::Result<LockfileDependencies> getDependenciesFromLockfile(const std::string& lockfilePath);
