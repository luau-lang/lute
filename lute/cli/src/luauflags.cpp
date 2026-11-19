#include "lute/luauflags.h"

#include "Luau/Common.h"
#include "Luau/ExperimentalFlags.h"

#include <charconv>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <string_view>

static void enableAllLuauFlags()
{
    for (Luau::FValue<bool>* flag = Luau::FValue<bool>::list; flag; flag = flag->next)
    {
        if (strncmp(flag->name, "Luau", 4) == 0 && !Luau::isAnalysisFlagExperimental(flag->name))
            flag->value = true;
    }
}

static void setAllLuauFlags(bool state)
{
    for (Luau::FValue<bool>* flag = Luau::FValue<bool>::list; flag; flag = flag->next)
    {
        if (strncmp(flag->name, "Luau", 4) == 0)
            flag->value = state;
    }
}

template<typename T>
static Luau::FValue<T>* findLuauFlag(std::string_view name)
{
    for (Luau::FValue<T>* flag = Luau::FValue<T>::list; flag; flag = flag->next)
    {
        if (name == flag->name)
            return flag;

        if (flag->version != 0 && name == std::string(flag->name) + std::to_string(flag->version))
            return flag;
    }

    return nullptr;
}

static void setLuauFlag(std::string_view name, bool state)
{
    if (Luau::FValue<bool>* flag = findLuauFlag<bool>(name))
        flag->value = state;
    else if (findLuauFlag<int>(name))
        fprintf(stderr, "Warning: flag '%.*s' expects an integer value.\n", int(name.length()), name.data());
    else
        fprintf(stderr, "Warning: unrecognized flag '%.*s'.\n", int(name.length()), name.data());
}

static void setLuauIntFlag(std::string_view name, int value)
{
    if (Luau::FValue<int>* flag = findLuauFlag<int>(name))
        flag->value = value;
    else if (findLuauFlag<bool>(name))
        fprintf(stderr, "Warning: flag '%.*s' expects a boolean value.\n", int(name.length()), name.data());
    else
        fprintf(stderr, "Warning: unrecognized flag '%.*s'.\n", int(name.length()), name.data());
}

static bool parseInt(std::string_view text, int& result)
{
    auto [end, error] = std::from_chars(text.data(), text.data() + text.size(), result);
    return error == std::errc() && end == text.data() + text.size();
}

static void setLuauFlagsFromList(const char* list)
{
    std::string_view rest = list;

    while (!rest.empty())
    {
        size_t ending = rest.find(',');
        std::string_view element = rest.substr(0, ending);

        if (size_t separator = element.find('='); separator != std::string_view::npos)
        {
            std::string_view key = element.substr(0, separator);
            std::string_view value = element.substr(separator + 1);

            if (value == "true" || value == "True")
                setLuauFlag(key, true);
            else if (value == "false" || value == "False")
                setLuauFlag(key, false);
            else if (int number = 0; parseInt(value, number))
                setLuauIntFlag(key, number);
            else
                fprintf(
                    stderr, "Warning: unrecognized value '%.*s' for flag '%.*s'.\n", int(value.length()), value.data(), int(key.length()), key.data()
                );
        }
        else
        {
            if (element == "true" || element == "True")
                setAllLuauFlags(true);
            else if (element == "false" || element == "False")
                setAllLuauFlags(false);
            else if (!element.empty())
                setLuauFlag(element, true);
        }

        if (ending != std::string_view::npos)
            rest.remove_prefix(ending + 1);
        else
            break;
    }
}

void setLuauFlags()
{
    enableAllLuauFlags();

    // Individual flags can be overridden here as needed, e.g.:
    // setLuauFlag("LuauSomeFlagThatCausedARegression", false);

    if (const char* list = std::getenv("LUTE_FFLAGS"))
        setLuauFlagsFromList(list);
}
