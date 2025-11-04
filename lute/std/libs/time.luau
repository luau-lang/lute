--!strict
-- @std/time
-- Provides utility functions for time durations

local NANOS_PER_SEC = 1_000_000_000
local NANOS_PER_MILLI = 1_000_000
local NANOS_PER_MICRO = 1_000
local MILLIS_PER_SEC = 1_000
local MICROS_PER_SEC = 1_000_000
local SECS_PER_MINUTE = 60
local MINS_PER_HOUR = 60
local HOURS_PER_DAY = 24
local DAYS_PER_WEEK = 7

type durationdata = {
	_seconds: number,
	_nanoseconds: number,
}

local time = {}

local duration = {}
duration.__index = duration

type durationinterface = typeof(duration)
export type duration = setmetatable<durationdata, durationinterface>

function duration.create(seconds: number, nanoseconds: number): duration
	local self = {
		_seconds = seconds,
		_nanoseconds = nanoseconds,
	}

	return setmetatable(self, duration)
end

function duration.seconds(seconds: number): duration
	return duration.create(seconds, 0)
end

function duration.milliseconds(milliseconds: number): duration
	local seconds = math.floor(milliseconds / MILLIS_PER_SEC)
	local nanoseconds = (milliseconds % MILLIS_PER_SEC) * NANOS_PER_MILLI

	return duration.create(seconds, nanoseconds)
end

function duration.microseconds(microseconds: number): duration
	local seconds = math.floor(microseconds / MICROS_PER_SEC)
	local nanoseconds = (microseconds % MICROS_PER_SEC) * NANOS_PER_MICRO

	return duration.create(seconds, nanoseconds)
end

function duration.nanoseconds(nanoseconds: number): duration
	local seconds = math.floor(nanoseconds / NANOS_PER_SEC)
	local nanosecondsRemaining = nanoseconds % NANOS_PER_SEC

	return duration.create(seconds, nanosecondsRemaining)
end

function duration.minutes(minutes: number): duration
	return duration.create(minutes * SECS_PER_MINUTE, 0)
end

function duration.hours(hours: number): duration
	return duration.create(hours * MINS_PER_HOUR * SECS_PER_MINUTE, 0)
end

function duration.days(days: number): duration
	return duration.create(days * HOURS_PER_DAY * MINS_PER_HOUR * SECS_PER_MINUTE, 0)
end

function duration.weeks(weeks: number): duration
	return duration.create(weeks * DAYS_PER_WEEK * HOURS_PER_DAY * MINS_PER_HOUR * SECS_PER_MINUTE, 0)
end

function duration.subsecmillis(self: duration): number
	return math.floor(self._nanoseconds / NANOS_PER_MILLI)
end

function duration.subsecmicros(self: duration): number
	return math.floor(self._nanoseconds / NANOS_PER_MICRO)
end

function duration.subsecnanos(self: duration): number
	return self._nanoseconds
end

function duration.toseconds(self: duration): number
	return self._seconds + self._nanoseconds / NANOS_PER_SEC
end

function duration.tomilliseconds(self: duration): number
	return self._seconds * MILLIS_PER_SEC + self:subsecmillis()
end

function duration.tomicroseconds(self: duration): number
	return self._seconds * MICROS_PER_SEC + self:subsecmicros()
end

function duration.tonanoseconds(self: duration): number
	return self._seconds * NANOS_PER_SEC + self:subsecnanos()
end

function duration.__add(a: duration, b: duration): duration
	local seconds = a._seconds + b._seconds
	local nanoseconds = a._nanoseconds + b._nanoseconds

	if nanoseconds >= NANOS_PER_SEC then
		seconds += 1
		nanoseconds -= NANOS_PER_SEC
	end

	return duration.create(seconds, nanoseconds)
end

function duration.__sub(a: duration, b: duration): duration
	local seconds = a._seconds - b._seconds
	local nanoseconds = a._nanoseconds - b._nanoseconds

	if nanoseconds < 0 then
		seconds -= 1
		nanoseconds += NANOS_PER_SEC
	end

	return duration.create(seconds, nanoseconds)
end

function duration.__mul(a: duration, b: number): duration
	local seconds = a._seconds * b
	local nanoseconds = a._nanoseconds * b

	seconds += math.floor(nanoseconds / NANOS_PER_SEC)
	nanoseconds %= NANOS_PER_SEC

	return duration.create(seconds, nanoseconds)
end

function duration.__div(a: duration, b: number): duration
	local seconds, extraSeconds = a._seconds / b, a._seconds % b
	local nanoseconds, extraNanos = a._nanoseconds / b, a._nanoseconds % b

	nanoseconds += (extraSeconds * NANOS_PER_SEC + extraNanos) / b

	return duration.create(seconds, nanoseconds)
end

function duration.__eq(a: duration, b: duration): boolean
	return a._seconds == b._seconds and a._nanoseconds == b._nanoseconds
end

function duration.__lt(a: duration, b: duration): boolean
	if a._seconds == b._seconds then
		return a._nanoseconds < b._nanoseconds
	end

	return a._seconds < b._seconds
end

function duration.__le(a: duration, b: duration): boolean
	if a._seconds == b._seconds then
		return a._nanoseconds <= b._nanoseconds
	end

	return a._seconds <= b._seconds
end

function duration.__tostring(self: duration): string
	return string.format("%d.%09d", self._seconds, self._nanoseconds)
end

time.duration = duration

return table.freeze(time)
