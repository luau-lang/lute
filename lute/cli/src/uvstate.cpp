#include "lute/uvstate.h"

#include "uv.h"

UvGlobalState::UvGlobalState(int argc, char** argv)
{
    uv_setup_args(argc, argv);
}

UvGlobalState::~UvGlobalState()
{
    uv_library_shutdown();
}
