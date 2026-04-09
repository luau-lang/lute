--!strict
-- @std/time
-- Provides utility functions for time

local luteTime = require("@lute/time")
local duration = require("@self/duration")

local time = {}

--- An opaque span of time.
export type Duration = duration.Duration
--- An opaque point in time, used with `time.since` to measure elapsed time.
export type Instant = luteTime.Instant

time.duration = duration

--- Returns the current point in time as an `Instant`.
function time.now(): Instant
	return luteTime.now()
end

--- Returns the number of seconds elapsed since `instant`.
function time.since(instant: Instant): number
	return luteTime.since(instant)
end

return table.freeze(time)
