#pragma once
#include <string>

class LuteReporter;

struct ProfileOptions
{
    std::string filename;
    int frequency = 10000;
};

int cliMain(int argc, char** argv, LuteReporter& reporter);
