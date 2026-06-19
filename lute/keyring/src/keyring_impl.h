#pragma once

#include <optional>
#include <string>

// Functions returning std::optional<std::string> use std::nullopt for success
// and a non-empty value for a human-readable error message.

namespace keyring
{

bool isSupported();

struct LookupResult
{
    std::optional<std::string> password;
    std::optional<std::string> error;
};

LookupResult getPassword(const std::string& service, const std::string& account);

std::optional<std::string> setPassword(const std::string& service, const std::string& account, const std::string& password);

// Idempotent: succeeds whether or not the entry existed.
std::optional<std::string> deletePassword(const std::string& service, const std::string& account);

} // namespace keyring
