#include "ca_certs.h"

#include "generated/cacerts.h"

#include <string_view>

namespace net::client
{

namespace
{
constexpr std::string_view kCACertPath = "@cacerts/cacert.pem";

std::string_view findEmbeddedCABundle()
{
    for (const auto& [path, contents] : lutecacerts)
    {
        if (path == kCACertPath)
            return contents;
    }
    return {};
}
} // namespace

void applyEmbeddedCACerts(CURL* curl)
{
    if (!curl)
        return;

    static const std::string_view pem = findEmbeddedCABundle();

    if (!pem.empty())
    {
        curl_blob blob{};
        blob.data = const_cast<char*>(pem.data());
        blob.len = pem.size();
        blob.flags = CURL_BLOB_NOCOPY;
        curl_easy_setopt(curl, CURLOPT_CAINFO_BLOB, &blob);
    }

    // The blob (when present) supersedes any compile-time CAINFO/CAPATH
    curl_easy_setopt(curl, CURLOPT_CAINFO, static_cast<const char*>(nullptr));
    curl_easy_setopt(curl, CURLOPT_CAPATH, static_cast<const char*>(nullptr));
}

} // namespace net::client
