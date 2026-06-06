#include "lute/stdlib.h"

StdLibModuleResult getStdLibModule(std::string_view)
{
    return {StdLibModuleType::NotFound};
}
