#include "lute/climain.h"
#include "lute/clireporter.h"
#include "lute/uvstate.h"

#include <cstdio>

int main(int argc, char** argv)
{
    // Disable buffering on stdout/stderr so output appears immediately
    // when running as a subprocess (e.g., from C# Process or other hosts)
    setvbuf(stdout, nullptr, _IONBF, 0);
    setvbuf(stderr, nullptr, _IONBF, 0);

    UvGlobalState uvState(argc, argv);
    CLIReporter reporter;
    return cliMain(argc, argv, reporter);
}
