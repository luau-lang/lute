#pragma once

#include "lute/requireutils.h"

#include "Luau/Require.h"
#include "lute/requirevfs.h"

#include <string>

void requireConfigInit(luarequire_Configuration* config);

struct RequireCtx
{
    RequireVfs vfs;
};
