#pragma once

#include "lua.h"
#include "lualib.h"
#include "uv.h"
#include <string>

// open the library as a standard global luau library
int luaopen_time(lua_State* L);
// open the library as a table on top of the stack
int luteopen_time(lua_State* L);

static const char kInstantType[] = "instant";
static const char kDurationType[] = "duration";
static const char kDurationLibraryIdentifier[] = "duration";

// exposed utils
double getSecondsFromTimespec(uv_timespec64_t timespec);
uv_timespec64_t getTimespecFromDuration(lua_State* L, int idx);

namespace duration
{
int lua_nanoseconds(lua_State* L);
int lua_microseconds(lua_State* L);
int lua_milliseconds(lua_State* L);
int lua_seconds(lua_State* L);
int lua_minutes(lua_State* L);
int lua_hours(lua_State* L);
int lua_days(lua_State* L);
int lua_weeks(lua_State* L);

static const luaL_Reg lib[] = {
    {"nanoseconds", lua_nanoseconds},
    {"microseconds", lua_microseconds},
    {"milliseconds", lua_milliseconds},
    {"seconds", lua_seconds},
    {"minutes", lua_minutes},
    {"hours", lua_hours},
    {"days", lua_days},
    {"weeks", lua_weeks},

    {nullptr, nullptr}
};

} // namespace duration

namespace libtime
{
int lua_now(lua_State* L);
int lua_since(lua_State* L);

static const luaL_Reg lib[] = {
    {"now", lua_now},
    {"since", lua_since},

    {nullptr, nullptr},
};

static const std::string properties[] = {
    kDurationLibraryIdentifier,
};

} // namespace libtime
