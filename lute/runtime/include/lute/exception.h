#pragma once

#include <stdexcept>

class LuteException : public std::runtime_error
{
public:
    explicit LuteException(const std::string& message)
        : std::runtime_error(message)
    {
    }
};
