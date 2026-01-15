#pragma once

struct lua_State;

void profilerStart(lua_State* L, int frequency);
void profilerStop();
void profilerDump(const char* path);
