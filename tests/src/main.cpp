#define DOCTEST_CONFIG_IMPLEMENT
#include "lute/uvstate.h"

#include "doctest.h"

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
