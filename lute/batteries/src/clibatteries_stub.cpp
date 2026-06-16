#include "lute/clibatteries.h"

BatteryModuleResult getBatteryModule(std::string_view)
{
    return {BatteryModuleType::NotFound};
}
