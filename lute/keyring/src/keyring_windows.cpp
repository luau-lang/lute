#include "keyring_impl.h"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <wincred.h>

namespace keyring
{

namespace
{

std::wstring toWide(const std::string& s)
{
    if (s.empty())
        return {};

    int needed = MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0);
    if (needed <= 0)
        return {};

    std::wstring out(static_cast<size_t>(needed), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), out.data(), needed);
    return out;
}

// Wincred keys credentials by a single TargetName, so we embed (service, account) into it.
std::wstring makeTarget(const std::string& service, const std::string& account)
{
    return toWide(service + "/" + account);
}

std::string lastErrorString(DWORD code)
{
    LPWSTR buf = nullptr;
    DWORD n = FormatMessageW(
        FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
        nullptr,
        code,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        reinterpret_cast<LPWSTR>(&buf),
        0,
        nullptr
    );

    std::string narrow;
    if (buf && n > 0)
    {
        int needed = WideCharToMultiByte(CP_UTF8, 0, buf, static_cast<int>(n), nullptr, 0, nullptr, nullptr);
        if (needed > 0)
        {
            narrow.resize(static_cast<size_t>(needed));
            WideCharToMultiByte(CP_UTF8, 0, buf, static_cast<int>(n), narrow.data(), needed, nullptr, nullptr);
        }
    }
    if (buf)
        LocalFree(buf);

    if (narrow.empty())
        return "error " + std::to_string(static_cast<unsigned long>(code));

    while (!narrow.empty() && (narrow.back() == '\r' || narrow.back() == '\n' || narrow.back() == ' '))
        narrow.pop_back();
    return narrow;
}

} // namespace

bool isSupported()
{
    return true;
}

LookupResult getPassword(const std::string& service, const std::string& account)
{
    std::wstring target = makeTarget(service, account);
    PCREDENTIALW cred = nullptr;

    if (!CredReadW(target.c_str(), CRED_TYPE_GENERIC, 0, &cred))
    {
        DWORD err = GetLastError();
        if (err == ERROR_NOT_FOUND)
            return {};
        return LookupResult{std::nullopt, "CredRead failed: " + lastErrorString(err)};
    }

    std::string password(reinterpret_cast<const char*>(cred->CredentialBlob), static_cast<size_t>(cred->CredentialBlobSize));
    CredFree(cred);
    return LookupResult{std::move(password), std::nullopt};
}

std::optional<std::string> setPassword(const std::string& service, const std::string& account, const std::string& password)
{
    std::wstring target = makeTarget(service, account);
    std::wstring user = toWide(account);

    CREDENTIALW cred = {};
    cred.Type = CRED_TYPE_GENERIC;
    cred.TargetName = target.data();
    cred.UserName = user.data();
    cred.CredentialBlobSize = static_cast<DWORD>(password.size());
    cred.CredentialBlob = const_cast<LPBYTE>(reinterpret_cast<const BYTE*>(password.data()));
    cred.Persist = CRED_PERSIST_LOCAL_MACHINE;

    if (!CredWriteW(&cred, 0))
        return "CredWrite failed: " + lastErrorString(GetLastError());

    return std::nullopt;
}

std::optional<std::string> deletePassword(const std::string& service, const std::string& account)
{
    std::wstring target = makeTarget(service, account);

    if (!CredDeleteW(target.c_str(), CRED_TYPE_GENERIC, 0))
    {
        DWORD err = GetLastError();
        if (err == ERROR_NOT_FOUND)
            return std::nullopt;
        return "CredDelete failed: " + lastErrorString(err);
    }

    return std::nullopt;
}

} // namespace keyring
