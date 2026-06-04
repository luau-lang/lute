#include "lute/options.h"

Luau::CompileOptions copts()
{
    Luau::CompileOptions result = {};
    result.optimizationLevel = 2;
    result.debugLevel = 1;
    result.typeInfoLevel = 0;
    result.coverageLevel = 0;

    return result;
}
