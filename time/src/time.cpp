#include "lute/time.h"
#include "lua.h"
#include "lualib.h"
#include "uv.h"

#include <cmath>
#include <cstdint>
#include <iterator>
#include <assert.h>

const int64_t NANOSECONDS_PER_SECOND = 1000000000;
const int64_t MICROSECONDS_PER_SECOND = 1000000;
const int64_t MILLISECONDS_PER_SECOND = 1000;
const int64_t SECONDS_PER_MINUTE = 60;
const int64_t SECONDS_PER_HOUR = 3600;
const int64_t SECONDS_PER_DAY = 86400;
const int64_t SECONDS_PER_WEEK = 604800;
const int64_t NANOSECONDS_PER_MICROSECOND = 1000;
const int64_t NANOSECONDS_PER_MILLISECOND = 1000000;

// Timespec helpers
static float_t diffTimespecs(uv_timespec64_t left, uv_timespec64_t right)
{
    int64_t secondsDiff = left.tv_sec - right.tv_sec;
    int32_t nanosecondsDiff = left.tv_nsec - right.tv_nsec;

    if (nanosecondsDiff < 0)
    {
        secondsDiff -= 1;
        nanosecondsDiff += NANOSECONDS_PER_SECOND;
    };

    return static_cast<float_t>(secondsDiff + (nanosecondsDiff / 1e9));
}

static float_t sinceTimespec(uv_timespec64_t timespec)
{
    uv_timespec64_t now;
    uv_clock_gettime(UV_CLOCK_MONOTONIC, &now);

    return diffTimespecs(now, timespec);
}

static double getSecondsFromTimespec(uv_timespec64_t timespec)
{
    return static_cast<double>(timespec.tv_sec) + static_cast<double>(timespec.tv_nsec) / NANOSECONDS_PER_SECOND;
}

// Durations

// returns the address of the timespec from the duration on the stack
static uv_timespec64_t getTimespecFromDuration(lua_State* L, int idx)
{
    return *static_cast<uv_timespec64_t*>(luaL_checkudata(L, idx, kDurationType));
}

// creates a userdata, and returns a fresh timespec pointer to it
static int createDurationFromTimespec(lua_State* L, uv_timespec64_t timespec)
{
    uv_timespec64_t* duration = static_cast<uv_timespec64_t*>(lua_newuserdatatagged(L, sizeof(uv_timespec64_t), kDurationTag));
    *duration = timespec;

    luaL_getmetatable(L, kDurationType);
    lua_setmetatable(L, -2);

    return 1;
}

static int createDurationFromSeconds(lua_State* L, double seconds)
{
    return createDurationFromTimespec(L, {static_cast<int64_t>(seconds), static_cast<int32_t>(fmod(seconds, 1) * NANOSECONDS_PER_SECOND)});
}

// Duration methods
static int duration_tonanoseconds(lua_State* L)
{
    uv_timespec64_t timespec = getTimespecFromDuration(L, 1);
    lua_pushnumber(L, static_cast<double>(timespec.tv_sec * NANOSECONDS_PER_SECOND) + timespec.tv_nsec);
    return 1;
}

static int duration_tomicroseconds(lua_State* L)
{
    uv_timespec64_t timespec = getTimespecFromDuration(L, 1);
    lua_pushnumber(L, getSecondsFromTimespec(timespec) * MICROSECONDS_PER_SECOND);
    return 1;
}

static int duration_tomilliseconds(lua_State* L)
{
    uv_timespec64_t timespec = getTimespecFromDuration(L, 1);
    lua_pushnumber(L, getSecondsFromTimespec(timespec) * MILLISECONDS_PER_SECOND);
    return 1;
}

static int duration_toseconds(lua_State* L)
{
    uv_timespec64_t timespec = getTimespecFromDuration(L, 1);
    lua_pushnumber(L, getSecondsFromTimespec(timespec));
    return 1;
}

static int duration_tominutes(lua_State* L)
{
    uv_timespec64_t timespec = getTimespecFromDuration(L, 1);
    lua_pushnumber(L, getSecondsFromTimespec(timespec) / SECONDS_PER_MINUTE);
    return 1;
}

static int duration_tohours(lua_State* L)
{
    uv_timespec64_t timespec = getTimespecFromDuration(L, 1);
    lua_pushnumber(L, getSecondsFromTimespec(timespec) / SECONDS_PER_HOUR);
    return 1;
}

static int duration_todays(lua_State* L)
{
    uv_timespec64_t timespec = getTimespecFromDuration(L, 1);
    lua_pushnumber(L, getSecondsFromTimespec(timespec) / SECONDS_PER_DAY);
    return 1;
}

static int duration_toweeks(lua_State* L)
{
    uv_timespec64_t timespec = getTimespecFromDuration(L, 1);
    lua_pushnumber(L, getSecondsFromTimespec(timespec) / SECONDS_PER_WEEK);
    return 1;
}

static int duration_subsecnanos(lua_State* L)
{
    uv_timespec64_t timespec = getTimespecFromDuration(L, 1);
    lua_pushnumber(L, timespec.tv_nsec);
    return 1;
}

static int duration_subsecmicros(lua_State* L)
{
    uv_timespec64_t timespec = getTimespecFromDuration(L, 1);
    lua_pushnumber(L, static_cast<double>(timespec.tv_nsec) / NANOSECONDS_PER_MICROSECOND);
    return 1;
}

static int duration_subsecmillis(lua_State* L)
{
    uv_timespec64_t timespec = getTimespecFromDuration(L, 1);
    lua_pushnumber(L, static_cast<double>(timespec.tv_nsec) / NANOSECONDS_PER_MILLISECOND);
    return 1;
}

// Metamethods
static int duration__tostring(lua_State* L)
{
    uv_timespec64_t timespec = getTimespecFromDuration(L, 1);

    // fix os-specific format string difference between macos/windows and linux
    lua_pushfstring(L, "%lld.%09d", static_cast<long long int>(timespec.tv_sec), timespec.tv_nsec);
    return 1;
}

static int duration__add(lua_State* L)
{
    uv_timespec64_t left = getTimespecFromDuration(L, 1);
    uv_timespec64_t right = getTimespecFromDuration(L, 2);

    uv_timespec64_t result = {left.tv_sec + right.tv_sec, left.tv_nsec + right.tv_nsec};
    if (result.tv_nsec > NANOSECONDS_PER_SECOND)
    {
        result.tv_sec += 1;
        result.tv_nsec -= NANOSECONDS_PER_SECOND;
    }

    return createDurationFromTimespec(L, result);
}

static int duration__sub(lua_State* L)
{
    uv_timespec64_t left = getTimespecFromDuration(L, 1);
    uv_timespec64_t right = getTimespecFromDuration(L, 2);

    uv_timespec64_t result = {left.tv_sec - right.tv_sec, left.tv_nsec - right.tv_nsec};
    if (result.tv_nsec < 0)
    {
        result.tv_sec -= 1;
        result.tv_nsec += NANOSECONDS_PER_SECOND;
    }

    return createDurationFromTimespec(L, {result.tv_sec >= 0 ? result.tv_sec : 0, result.tv_nsec >= 0 ? result.tv_nsec : 0});
}

static int duration__eq(lua_State* L)
{
    uv_timespec64_t left = getTimespecFromDuration(L, 1);
    uv_timespec64_t right = getTimespecFromDuration(L, 2);

    lua_pushboolean(L, left.tv_sec == right.tv_sec && left.tv_nsec == right.tv_nsec);
    return 1;
}

static int duration__lt(lua_State* L)
{
    uv_timespec64_t left = getTimespecFromDuration(L, 1);
    uv_timespec64_t right = getTimespecFromDuration(L, 2);

    lua_pushboolean(L, left.tv_sec < right.tv_sec || (left.tv_sec == right.tv_sec && left.tv_nsec < right.tv_nsec));
    return 1;
}

static int duration__le(lua_State* L)
{
    uv_timespec64_t left = getTimespecFromDuration(L, 1);
    uv_timespec64_t right = getTimespecFromDuration(L, 2);

    lua_pushboolean(L, left.tv_sec < right.tv_sec || (left.tv_sec == right.tv_sec && left.tv_nsec <= right.tv_nsec));
    return 1;
}

// Instants
static uv_timespec64_t getTimespecFromInstant(lua_State* L, int idx)
{
    return *static_cast<uv_timespec64_t*>(luaL_checkudata(L, idx, kInstantType));
}

// Methods
static int instant_elapsed(lua_State* L)
{
    lua_pushnumber(L, sinceTimespec(getTimespecFromInstant(L, 1)));
    return 1;
}

// Metamethods
static int instant__sub(lua_State* L)
{
    uv_timespec64_t left = getTimespecFromInstant(L, 1);
    uv_timespec64_t right = getTimespecFromInstant(L, 2);

    return createDurationFromSeconds(L, static_cast<double>(diffTimespecs(left, right)));
}

namespace duration
{
int lua_nanoseconds(lua_State* L)
{
    // int32_t doesn't have enough precision for nanoseconds
    int64_t nanoseconds = static_cast<int64_t>(luaL_checknumber(L, 1));
    if (nanoseconds < 0)
        luaL_error(L, "duration cannot be negative");

    int64_t seconds = 0;
    if (nanoseconds > NANOSECONDS_PER_SECOND)
    {
        seconds = static_cast<int64_t>(nanoseconds / NANOSECONDS_PER_SECOND);
        nanoseconds = static_cast<int64_t>(fmod(nanoseconds, NANOSECONDS_PER_SECOND));
    }

    return createDurationFromTimespec(L, {seconds, static_cast<int32_t>(nanoseconds)});
}

int lua_microseconds(lua_State* L)
{
    double microseconds = luaL_checknumber(L, 1);
    if (microseconds < 0)
        luaL_error(L, "duration cannot be negative");

    int64_t seconds = 0;
    if (microseconds > MICROSECONDS_PER_SECOND)
    {
        seconds = static_cast<int64_t>(microseconds / MICROSECONDS_PER_SECOND);
        microseconds = fmod(microseconds, MICROSECONDS_PER_SECOND);
    }

    return createDurationFromTimespec(L, {seconds, static_cast<int32_t>(microseconds * NANOSECONDS_PER_MICROSECOND)});
}

int lua_milliseconds(lua_State* L)
{
    double milliseconds = luaL_checknumber(L, 1);
    if (milliseconds < 0)
        luaL_error(L, "duration cannot be negative");

    int64_t seconds = 0;
    if (milliseconds > MILLISECONDS_PER_SECOND)
    {
        seconds = static_cast<int64_t>(milliseconds / MILLISECONDS_PER_SECOND);
        milliseconds = fmod(milliseconds, MILLISECONDS_PER_SECOND);
    }

    return createDurationFromTimespec(L, {seconds, static_cast<int32_t>(milliseconds * NANOSECONDS_PER_MILLISECOND)});
}

int lua_seconds(lua_State* L)
{
    double seconds = luaL_checknumber(L, 1);
    if (seconds < 0)
        luaL_error(L, "duration cannot be negative");

    return createDurationFromSeconds(L, seconds);
}

int lua_minutes(lua_State* L)
{
    double minutes = luaL_checknumber(L, 1);
    if (minutes < 0)
        luaL_error(L, "duration cannot be negative");

    return createDurationFromSeconds(L, minutes * SECONDS_PER_MINUTE);
}

int lua_hours(lua_State* L)
{
    double hours = luaL_checknumber(L, 1);
    if (hours < 0)
        luaL_error(L, "duration cannot be negative");

    // hours can still overflow
    if (hours > (pow(2, 63) / SECONDS_PER_HOUR))
    {
        luaL_error(L, "duration is too large");
        return 0;
    }

    return createDurationFromSeconds(L, hours * SECONDS_PER_HOUR);
}

int lua_days(lua_State* L)
{
    double days = luaL_checknumber(L, 1);
    if (days < 0)
        luaL_error(L, "duration cannot be negative");

    // account for overflow
    if (days > (pow(2, 63) / SECONDS_PER_DAY))
    {
        luaL_error(L, "duration is too large");
        return 0;
    }

    return createDurationFromSeconds(L, days * SECONDS_PER_DAY);
}

int lua_weeks(lua_State* L)
{
    double weeks = luaL_checknumber(L, 1);
    if (weeks < 0)
        luaL_error(L, "duration cannot be negative");

    // account for overflow
    if (weeks > (pow(2, 63) / SECONDS_PER_WEEK))
        luaL_error(L, "duration is too large");

    return createDurationFromSeconds(L, weeks * SECONDS_PER_WEEK);
}

} // namespace duration

namespace libtime
{
int lua_now(lua_State* L)
{
    uv_timespec64_t now;

    int status = uv_clock_gettime(UV_CLOCK_MONOTONIC, &now);
    assert(status == 0);

    uv_timespec64_t* timespec = static_cast<uv_timespec64_t*>(lua_newuserdatatagged(L, sizeof(uv_timespec64_t), kInstantTag));

    *timespec = now;

    luaL_getmetatable(L, kInstantType);
    lua_setmetatable(L, -2);

    return 1;
}

int lua_since(lua_State* L)
{
    lua_pushnumber(L, sinceTimespec(getTimespecFromInstant(L, 1)));
    return 1;
}
} // namespace libtime

static void init_duration_lib(lua_State* L)
{
    luaL_newmetatable(L, kDurationType);

    // Protect metatable from being changed
    lua_pushstring(L, "The metatable is locked");
    lua_setfield(L, -2, "__metatable");

    lua_pushcfunction(L, duration__tostring, "Duration__tostring");
    lua_setfield(L, -2, "__tostring");

    lua_pushcfunction(L, duration__add, "Duration__add");
    lua_setfield(L, -2, "__add");

    lua_pushcfunction(L, duration__sub, "Duration__sub");
    lua_setfield(L, -2, "__sub");

    lua_pushcfunction(L, duration__eq, "Duration__eq");
    lua_setfield(L, -2, "__eq");

    lua_pushcfunction(L, duration__lt, "Duration__lt");
    lua_setfield(L, -2, "__lt");

    lua_pushcfunction(L, duration__le, "Duration__le");
    lua_setfield(L, -2, "__le");

    // __index table
    lua_createtable(L, 0, 11);

    lua_pushcfunction(L, duration_tonanoseconds, "Duration__tonanoseconds");
    lua_setfield(L, -2, "tonanoseconds");

    lua_pushcfunction(L, duration_tomicroseconds, "Duration__tomicroseconds");
    lua_setfield(L, -2, "tomicroseconds");

    lua_pushcfunction(L, duration_tomilliseconds, "Duration__tomilliseconds");
    lua_setfield(L, -2, "tomilliseconds");

    lua_pushcfunction(L, duration_toseconds, "Duration__toseconds");
    lua_setfield(L, -2, "toseconds");

    lua_pushcfunction(L, duration_tominutes, "Duration__tominutes");
    lua_setfield(L, -2, "tominutes");

    lua_pushcfunction(L, duration_tohours, "Duration__tohours");
    lua_setfield(L, -2, "tohours");

    lua_pushcfunction(L, duration_todays, "Duration__todays");
    lua_setfield(L, -2, "todays");

    lua_pushcfunction(L, duration_toweeks, "Duration__toweeks");
    lua_setfield(L, -2, "toweeks");

    lua_pushcfunction(L, duration_subsecnanos, "Duration__subsecnanos");
    lua_setfield(L, -2, "subsecnanos");

    lua_pushcfunction(L, duration_subsecmicros, "Duration__subsecmicros");
    lua_setfield(L, -2, "subsecmicros");

    lua_pushcfunction(L, duration_subsecmillis, "Duration__subsecmillis");
    lua_setfield(L, -2, "subsecmillis");

    lua_setreadonly(L, -1, true);

    // set __index
    lua_setfield(L, -2, "__index");

    // metatable is now in stack spot 1
    lua_setreadonly(L, -1, true);

    lua_pop(L, 1);
}

static void init_instant_lib(lua_State* L)
{
    // metatable is in stack spot 1
    luaL_newmetatable(L, kInstantType);

    lua_pushstring(L, "The metatable is locked");
    lua_setfield(L, -2, "__metatable");

    lua_pushcfunction(L, instant__sub, "Instant__sub");
    lua_setfield(L, -2, "__sub");

    // __index table
    lua_createtable(L, 0, 2);

    lua_pushcfunction(L, instant_elapsed, "Instant__elapsed");
    lua_setfield(L, -2, "elapsed");

    lua_setreadonly(L, -1, true);

    // __index set
    lua_setfield(L, -2, "__index");

    lua_setreadonly(L, -1, true);

    lua_pop(L, 1);
}

static int init_luau_lib(lua_State* L)
{
    init_instant_lib(L);
    init_duration_lib(L);

    return 0;
}

int luaopen_time(lua_State* L)
{
    init_luau_lib(L);

    luaL_register(L, "time", libtime::lib);
    lua_setglobal(L, "time");

    return 1;
}

int luteopen_time(lua_State* L)
{
    init_luau_lib(L);

    lua_createtable(L, 0, std::size(libtime::lib) + std::size(libtime::properties));

    // Duration sub-table
    lua_createtable(L, 0, std::size(duration::lib));
    for (auto& [name, func] : duration::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }
    lua_setfield(L, -2, kDurationLibraryIdentifier);

    // Main time library
    for (auto& [name, func] : libtime::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    return 1;
}
