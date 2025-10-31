#include "lute/luauflags.h"

#include "Luau/Common.h"

#include <string_view>

static void setLuauFlag(std::string_view name, bool state)
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
    setLuauFlag("LuauAutocompleteAttributes", true);
}
