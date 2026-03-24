--!strict
-- Submodule of @std/time that provides utility functions for time durations

local time = require("@lute/time")

export type Duration = time.Duration

local duration = {}

function duration.nanoseconds(nanoseconds: number): Duration
	return time.duration.nanoseconds(nanoseconds)
end

function duration.microseconds(microseconds: number): Duration
	return time.duration.microseconds(microseconds)
end

function duration.milliseconds(milliseconds: number): Duration
	return time.duration.milliseconds(milliseconds)
end

function duration.seconds(seconds: number): Duration
	return time.duration.seconds(seconds)
end

function duration.minutes(minutes: number): Duration
	return time.duration.minutes(minutes)
end

function duration.hours(hours: number): Duration
	return time.duration.hours(hours)
end

function duration.days(days: number): Duration
	return time.duration.days(days)
end

function duration.weeks(weeks: number): Duration
	return time.duration.weeks(weeks)
end

return table.freeze(duration)
