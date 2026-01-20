#pragma once

struct lua_State;

void coverageInit(lua_State* L);
bool coverageActive();

void coverageTrack(lua_State* L, int funcindex);
void coverageDump(const char* path);
