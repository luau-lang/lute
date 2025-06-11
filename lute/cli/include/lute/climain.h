#pragma once

struct lua_State;
struct Runtime;

lua_State* setupCliState(Runtime& runtime);
int cliMain(int argc, char** argv);
