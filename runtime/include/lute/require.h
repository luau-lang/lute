#pragma once

#include "lute/requirevfs.h"

#include "Luau/Require.h"

#include <string>

void requireConfigInit(luarequire_Configuration* config);

struct RequireCtx
{
    RequireVfs vfs;
};
