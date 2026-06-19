#include "keyring_impl.h"

namespace keyring
{

namespace
{
constexpr const char* kUnsupported = "OS credential store not supported on this platform";
}

bool isSupported()
{
    return false;
}

LookupResult getPassword(const std::string&, const std::string&)
{
    return LookupResult{std::nullopt, std::string(kUnsupported)};
}

std::optional<std::string> setPassword(const std::string&, const std::string&, const std::string&)
{
    return std::string(kUnsupported);
}

std::optional<std::string> deletePassword(const std::string&, const std::string&)
{
    return std::string(kUnsupported);
}

} // namespace keyring
