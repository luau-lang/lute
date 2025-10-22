#pragma once

struct UvGlobalState
{
    UvGlobalState(const UvGlobalState&) = delete;
    UvGlobalState& operator=(const UvGlobalState&) = delete;
    UvGlobalState(UvGlobalState&&) = delete;
    UvGlobalState& operator=(UvGlobalState&&) = delete;

    UvGlobalState(int argc, char** argv);
    ~UvGlobalState();
};
