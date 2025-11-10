#include "lute/climain.h"
#include "lute/uvstate.h"

int main(int argc, char** argv)
{
    UvGlobalState uvState(argc, argv);
    return cliMain(argc, argv);
}
