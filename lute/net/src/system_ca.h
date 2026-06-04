#pragma once

typedef void CURL;

namespace net
{

// Configures `curl` to use the operating system's trusted CA store.
void applySystemCA(CURL* curl);

} // namespace net
