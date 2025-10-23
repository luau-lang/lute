#pragma once

#include "lute/bundlevfs.h"
#include "lute/clivfs.h"
#include "lute/requirevfs.h"

#include "Luau/Require.h"

#include <string>

void requireConfigInit(luarequire_Configuration* config);

struct RequireCtx
{
    RequireCtx();
    RequireCtx(CliVfs cliVfs);
    RequireCtx(BundleVfs bundleVfs);

    RequireVfs vfs;
};
