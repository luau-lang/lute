#include "system_ca.h"

#include "curl/curl.h"

#if defined(__linux__)
#include <sys/stat.h>
#endif

namespace net
{

#if defined(__linux__)
namespace
{

// Mirrors the lists in Go's crypto/x509/root_linux.go.
constexpr const char* kCAFiles[] = {
    "/etc/ssl/certs/ca-certificates.crt",                // Debian/Ubuntu/Gentoo etc.
    "/etc/pki/tls/certs/ca-bundle.crt",                  // Fedora/RHEL 6
    "/etc/ssl/ca-bundle.pem",                            // OpenSUSE
    "/etc/pki/tls/cacert.pem",                           // OpenELEC
    "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem", // CentOS/RHEL 7
    "/etc/ssl/cert.pem",                                 // Alpine Linux
};

constexpr const char* kCADirs[] = {
    "/etc/ssl/certs",     // SLES10/SLES11
    "/etc/pki/tls/certs", // Fedora/RHEL
};

const char* findPath(const char* const* paths, size_t count, bool wantDir)
{
    struct stat st;
    for (size_t i = 0; i < count; ++i)
    {
        if (::stat(paths[i], &st) != 0)
            continue;
        if (wantDir ? S_ISDIR(st.st_mode) : S_ISREG(st.st_mode))
            return paths[i];
    }
    return nullptr;
}

} // namespace
#endif

void applySystemCA(CURL* curl)
{
#if defined(_WIN32)
    curl_easy_setopt(curl, CURLOPT_SSL_OPTIONS, CURLSSLOPT_NATIVE_CA);
#elif defined(__APPLE__)
    // macOS 12+ always ships /etc/ssl/cert.pem
    curl_easy_setopt(curl, CURLOPT_CAINFO, "/etc/ssl/cert.pem");
#elif defined(__linux__)
    static const char* cafile = findPath(kCAFiles, sizeof(kCAFiles) / sizeof(kCAFiles[0]), false);
    static const char* capath = findPath(kCADirs, sizeof(kCADirs) / sizeof(kCADirs[0]), true);
    if (cafile)
        curl_easy_setopt(curl, CURLOPT_CAINFO, cafile);
    if (capath)
        curl_easy_setopt(curl, CURLOPT_CAPATH, capath);
#endif
}

} // namespace net
