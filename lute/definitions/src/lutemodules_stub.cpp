#include "lute/lutemodules.h"

LuteModuleResult getLuteModule(std::string_view)
{
    return {LuteModuleType::NotFound};
}
