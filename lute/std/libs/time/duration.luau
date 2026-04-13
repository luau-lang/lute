--!strict
-- Submodule of @std/time that provides utility functions for time durations

local time = require("@lute/time")

--- A span of time.
export type Duration = time.Duration

local duration = {}

--- Creates a `Duration` from a number of `seconds` and an additional number of nanoseconds, `subsecnanos`.
function duration.create(seconds: number, subsecnanos: number): Duration
	return time.duration.create(seconds, subsecnanos)
end

--- Creates a `Duration` from a number of nanoseconds.
function duration.nanoseconds(nanoseconds: number): Duration
	return time.duration.nanoseconds(nanoseconds)
end

--- Creates a `Duration` from a number of microseconds.
function duration.microseconds(microseconds: number): Duration
	return time.duration.microseconds(microseconds)
end

--- Creates a `Duration` from a number of milliseconds.
function duration.milliseconds(milliseconds: number): Duration
	return time.duration.milliseconds(milliseconds)
end

--- Creates a `Duration` from a number of seconds.
function duration.seconds(seconds: number): Duration
	return time.duration.seconds(seconds)
end

--- Creates a `Duration` from a number of minutes.
function duration.minutes(minutes: number): Duration
	return time.duration.minutes(minutes)
end

--- Creates a `Duration` from a number of hours.
function duration.hours(hours: number): Duration
	return time.duration.hours(hours)
end

--- Creates a `Duration` from a number of days.
function duration.days(days: number): Duration
	return time.duration.days(days)
end

--- Creates a `Duration` from a number of weeks.
function duration.weeks(weeks: number): Duration
	return time.duration.weeks(weeks)
end

return table.freeze(duration)
