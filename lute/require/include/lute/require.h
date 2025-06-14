#pragma once

#include "lute/clivfs.h"
#include "lute/requirevfs.h"

#include "Luau/Require.h"

#include <string>

void requireConfigInit(luarequire_Configuration* config);

struct RequireCtx
{
    RequireCtx();
    RequireCtx(CliVfs cliVfs);

    RequireVfs vfs;
};
