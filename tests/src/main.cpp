#define DOCTEST_CONFIG_IMPLEMENT
#include "doctest.h"

#include "lute/uvstate.h"

int main(int argc, char** argv)
{
    UvGlobalState uvState(argc, argv);

    doctest::Context context;
    context.applyCommandLine(argc, argv);

    int res = context.run();

    if (context.shouldExit())
        return res;

    return res;
}
