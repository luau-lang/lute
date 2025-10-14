#pragma once
#include <functional>
#include <string>

struct lua_State;
struct Runtime;

lua_State* setupCliState(Runtime& runtime, std::function<void(lua_State*)> preSandboxInit = nullptr);
int cliMain(int argc, char** argv);
bool runBytecode(Runtime& runtime, const std::string& bytecode, const std::string& chunkname, lua_State* GL, int program_argc, char** program_argv);