#include "lute/luauflags.h"

#include "Luau/Common.h"
#include "Luau/ExperimentalFlags.h"

#include <stdexcept>
#include <string_view>

static void enableAllLuauFlags()
{
    for (Luau::FValue<bool>* flag = Luau::FValue<bool>::list; flag; flag = flag->next)
    {
        if (strncmp(flag->name, "Luau", 4) == 0 && !Luau::isAnalysisFlagExperimental(flag->name))
            flag->value = true;
    }
}

[[maybe_unused]] static void setLuauFlag(std::string_view name, bool state)
{
    for (Luau::FValue<bool>* flag = Luau::FValue<bool>::list; flag; flag = flag->next)
    {
        if (name == flag->name)
        {
            flag->value = state;
            return;
        }
    }

    throw std::runtime_error("Unrecognized Luau flag");
}

void setLuauFlags()
{
    enableAllLuauFlags();

    // Individual flags can be overriden here as needed, e.g.:
    // setLuauFlag("LuauSomeFlagThatCausedARegression", false);
}
