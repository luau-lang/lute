#include "system_ca.h"

#include "curl/curl.h"

#include <cstdlib>

#if defined(__linux__)
#include <sys/stat.h>
#endif

namespace net
{

namespace
{

// libcurl ignores SSL_CERT_FILE / CURL_CA_BUNDLE once CURLOPT_CAINFO is set,
// and SSL_CERT_DIR / CURL_CA_PATH once CURLOPT_CAPATH is set. Apply them
// ourselves so a process-level bundle wins over the platform default.
const char* envOrNull(const char* name)
{
    const char* value = std::getenv(name);
    if (!value || value[0] == '\0')
        return nullptr;
    return value;
}

const char* caFileFromEnv()
{
    const char* sslCertFile = envOrNull("SSL_CERT_FILE");
    if (sslCertFile)
        return sslCertFile;
    return envOrNull("CURL_CA_BUNDLE");
}

const char* caDirFromEnv()
{
    const char* sslCertDir = envOrNull("SSL_CERT_DIR");
    if (sslCertDir)
        return sslCertDir;
    return envOrNull("CURL_CA_PATH");
}

#if defined(__linux__)

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

#endif

} // namespace

void applySystemCA(CURL* curl)
{
#if defined(_WIN32)
    curl_easy_setopt(curl, CURLOPT_SSL_OPTIONS, CURLSSLOPT_NATIVE_CA);
#elif defined(__APPLE__)
    // macOS 12+ always ships /etc/ssl/cert.pem. Prefer SSL_CERT_FILE / CURL_CA_BUNDLE.
    const char* cafile = caFileFromEnv();
    curl_easy_setopt(curl, CURLOPT_CAINFO, cafile ? cafile : "/etc/ssl/cert.pem");

    const char* capath = caDirFromEnv();
    if (capath)
        curl_easy_setopt(curl, CURLOPT_CAPATH, capath);
#elif defined(__linux__)
    const char* cafile = caFileFromEnv();
    if (!cafile)
        cafile = findPath(kCAFiles, sizeof(kCAFiles) / sizeof(kCAFiles[0]), false);
    if (cafile)
        curl_easy_setopt(curl, CURLOPT_CAINFO, cafile);

    const char* capath = caDirFromEnv();
    if (!capath)
        capath = findPath(kCADirs, sizeof(kCADirs) / sizeof(kCADirs[0]), true);
    if (capath)
        curl_easy_setopt(curl, CURLOPT_CAPATH, capath);
#endif
}

} // namespace net
