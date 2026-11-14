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

// libcurl ignores these once CURLOPT_CAINFO / CURLOPT_CAPATH are set. The curl
// tool reads them itself, in this order: CURL_CA_BUNDLE replaces the CA file
// and skips the other two; otherwise SSL_CERT_DIR is the CA directory and
// SSL_CERT_FILE is the CA file. Match that so enterprise bundles are trusted.
const char* envOrNull(const char* name)
{
    const char* value = std::getenv(name);
    if (!value || value[0] == '\0')
        return nullptr;
    return value;
}

struct CAEnv
{
    const char* file;
    const char* dir;
};

CAEnv caFromEnv()
{
    const char* bundle = envOrNull("CURL_CA_BUNDLE");
    if (bundle)
        return {bundle, nullptr};

    return {envOrNull("SSL_CERT_FILE"), envOrNull("SSL_CERT_DIR")};
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
#else
    CAEnv fromEnv = caFromEnv();
    const char* cafile = fromEnv.file;
    const char* capath = fromEnv.dir;

#if defined(__APPLE__)
    // macOS 12+ always ships /etc/ssl/cert.pem.
    if (!cafile)
        cafile = "/etc/ssl/cert.pem";
#elif defined(__linux__)
    if (!cafile)
        cafile = findPath(kCAFiles, sizeof(kCAFiles) / sizeof(kCAFiles[0]), false);
    // A file from the environment replaces the platform locations. The distro
    // directory remains only when the environment did not name a file.
    if (!fromEnv.file && !capath)
        capath = findPath(kCADirs, sizeof(kCADirs) / sizeof(kCADirs[0]), true);
#endif

    if (cafile)
        curl_easy_setopt(curl, CURLOPT_CAINFO, cafile);
    if (capath)
        curl_easy_setopt(curl, CURLOPT_CAPATH, capath);
#endif
}

} // namespace net
