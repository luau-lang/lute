#include "lute/climain.h"
#include "lute/clireporter.h"
#include "lute/uvstate.h"

int main(int argc, char** argv)
{
    UvGlobalState uvState(argc, argv);
    CLIReporter reporter;
    return cliMain(argc, argv, reporter);
}
