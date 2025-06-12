#pragma once

#include <string>

struct lua_State;
struct Runtime;

lua_State* setupCliState(Runtime& runtime);
bool runBytecode(Runtime& runtime, const std::string& bytecode, const std::string& chunkname, lua_State* GL);
int cliMain(int argc, char** argv);
