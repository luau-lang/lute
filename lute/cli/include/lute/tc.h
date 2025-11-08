#pragma once

#include "Luau/FileResolver.h"
#include "Luau/FileUtils.h"
#include "Luau/Frontend.h"

int typecheck(const std::vector<std::string>& sourceFiles);
