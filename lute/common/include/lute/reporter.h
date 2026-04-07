#pragma once

#include <cstdio>
#include <string>
#include <vector>

// Interface for reporting output and errors from CLI operations
class LuteReporter
{
public:
    virtual ~LuteReporter() = default;

    // Report an error message (typically to stderr)
    virtual void reportError(const std::string& message) = 0;

    // Report normal output (typically to stdout)
    virtual void reportOutput(const std::string& message) = 0;

    // Variadic template version for formatted error messages using printf-style format specifiers
    template<typename... Args>
    void formatError(const char* format, Args&&... args)
    {
        reportError(formatMessage(format, std::forward<Args>(args)...));
    }

    // Variadic template version for formatted output messages using printf-style format specifiers
    template<typename... Args>
    void formatOutput(const char* format, Args&&... args)
    {
        reportOutput(formatMessage(format, std::forward<Args>(args)...));
    }

private:
    // Format implementation using snprintf
    template<typename... Args>
    static std::string formatMessage(const char* format, Args&&... args)
    {
        // Calculate required buffer size
        int size = std::snprintf(nullptr, 0, format, args...);

        if (size > 0)
        {
            // Allocate buffer and format the string
            std::vector<char> buffer(size + 1);
            std::snprintf(buffer.data(), buffer.size(), format, args...);

            return std::string(buffer.data(), size);
        }

        // Fallback if formatting fails
        return std::string(format);
    }
};

// Concrete reporter that writes errors to stderr and output to stdout
class StderrReporter : public LuteReporter
{
public:
    void reportError(const std::string& message) override
    {
        std::fprintf(stderr, "%s\n", message.c_str());
    }

    void reportOutput(const std::string& message) override
    {
        std::fprintf(stdout, "%s\n", message.c_str());
    }
};
