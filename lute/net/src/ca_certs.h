#pragma once

#include "curl/curl.h"

namespace net::client
{

// Configures `curl` to verify peers against lute's embedded Mozilla CA bundle.
void applyEmbeddedCACerts(CURL* curl);

} // namespace net::client
