#include "lute/options.h"

static bool codegen = false;

Luau::CompileOptions copts()
{
    Luau::CompileOptions result = {};
    result.optimizationLevel = 2;
    result.debugLevel = 2;
    result.typeInfoLevel = 1;
    result.coverageLevel = 0;

    return result;
}

bool getCodegenEnabled()
{
    return codegen;
}

void setCodegenEnabled(bool enabled)
{
    codegen = enabled;
}
