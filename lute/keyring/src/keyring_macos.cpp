#include "keyring_impl.h"

#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>

namespace keyring
{

namespace
{

CFStringRef toCFString(const std::string& s)
{
    return CFStringCreateWithBytes(
        kCFAllocatorDefault,
        reinterpret_cast<const UInt8*>(s.data()),
        static_cast<CFIndex>(s.size()),
        kCFStringEncodingUTF8,
        false
    );
}

std::string osStatusToString(OSStatus status)
{
    CFStringRef message = SecCopyErrorMessageString(status, nullptr);
    if (!message)
        return "OSStatus " + std::to_string(static_cast<long>(status));

    char buf[256] = {};
    CFStringGetCString(message, buf, sizeof(buf), kCFStringEncodingUTF8);
    CFRelease(message);
    return std::string(buf) + " (OSStatus " + std::to_string(static_cast<long>(status)) + ")";
}

} // namespace

bool isSupported()
{
    return true;
}

LookupResult getPassword(const std::string& service, const std::string& account)
{
    CFStringRef cfService = toCFString(service);
    CFStringRef cfAccount = toCFString(account);

    const void* keys[] = {kSecClass, kSecAttrService, kSecAttrAccount, kSecReturnData, kSecMatchLimit};
    const void* values[] = {kSecClassGenericPassword, cfService, cfAccount, kCFBooleanTrue, kSecMatchLimitOne};
    CFDictionaryRef query =
        CFDictionaryCreate(kCFAllocatorDefault, keys, values, 5, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    CFTypeRef result = nullptr;
    OSStatus status = SecItemCopyMatching(query, &result);

    CFRelease(query);
    CFRelease(cfAccount);
    CFRelease(cfService);

    if (status == errSecItemNotFound)
        return {};

    if (status != errSecSuccess)
        return LookupResult{std::nullopt, "Keychain lookup failed: " + osStatusToString(status)};

    CFDataRef data = static_cast<CFDataRef>(result);
    std::string password(reinterpret_cast<const char*>(CFDataGetBytePtr(data)), static_cast<size_t>(CFDataGetLength(data)));
    CFRelease(result);
    return LookupResult{std::move(password), std::nullopt};
}

std::optional<std::string> setPassword(const std::string& service, const std::string& account, const std::string& password)
{
    CFStringRef cfService = toCFString(service);
    CFStringRef cfAccount = toCFString(account);
    CFDataRef cfPassword = CFDataCreate(
        kCFAllocatorDefault, reinterpret_cast<const UInt8*>(password.data()), static_cast<CFIndex>(password.size())
    );

    const void* queryKeys[] = {kSecClass, kSecAttrService, kSecAttrAccount};
    const void* queryValues[] = {kSecClassGenericPassword, cfService, cfAccount};
    CFDictionaryRef query = CFDictionaryCreate(
        kCFAllocatorDefault, queryKeys, queryValues, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks
    );

    const void* updateKeys[] = {kSecValueData};
    const void* updateValues[] = {cfPassword};
    CFDictionaryRef update = CFDictionaryCreate(
        kCFAllocatorDefault, updateKeys, updateValues, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks
    );

    OSStatus status = SecItemUpdate(query, update);
    CFRelease(update);
    CFRelease(query);

    if (status == errSecItemNotFound)
    {
        const void* addKeys[] = {kSecClass, kSecAttrService, kSecAttrAccount, kSecValueData};
        const void* addValues[] = {kSecClassGenericPassword, cfService, cfAccount, cfPassword};
        CFDictionaryRef add = CFDictionaryCreate(
            kCFAllocatorDefault, addKeys, addValues, 4, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks
        );
        status = SecItemAdd(add, nullptr);
        CFRelease(add);
    }

    CFRelease(cfPassword);
    CFRelease(cfAccount);
    CFRelease(cfService);

    if (status != errSecSuccess)
        return "Keychain write failed: " + osStatusToString(status);

    return std::nullopt;
}

std::optional<std::string> deletePassword(const std::string& service, const std::string& account)
{
    CFStringRef cfService = toCFString(service);
    CFStringRef cfAccount = toCFString(account);

    const void* keys[] = {kSecClass, kSecAttrService, kSecAttrAccount};
    const void* values[] = {kSecClassGenericPassword, cfService, cfAccount};
    CFDictionaryRef query =
        CFDictionaryCreate(kCFAllocatorDefault, keys, values, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    OSStatus status = SecItemDelete(query);

    CFRelease(query);
    CFRelease(cfAccount);
    CFRelease(cfService);

    if (status == errSecSuccess || status == errSecItemNotFound)
        return std::nullopt;

    return "Keychain delete failed: " + osStatusToString(status);
}

} // namespace keyring
