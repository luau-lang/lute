#pragma once
#include "lute/reporter.h"

#include <string>

struct lua_State;

struct ProfileOptions
{
    std::string filename;
    int frequency = 10000;
};

void profilerStart(lua_State* L, int frequency);
void profilerStop();
void profilerDump(const char* path, LuteReporter& reporter);
