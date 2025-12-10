#pragma once
#include <functional>
#include <string>

struct lua_State;
struct Runtime;
class LuteReporter;

int cliMain(int argc, char** argv, LuteReporter& reporter);
bool runBytecode(
    Runtime& runtime,
    const std::string& bytecode,
    const std::string& chunkname,
    lua_State* GL,
    int program_argc,
    char** program_argv,
    LuteReporter& reporter
);
