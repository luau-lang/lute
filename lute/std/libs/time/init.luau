--!strict
-- @std/time
-- Provides utility functions for time

local luteTime = require("@lute/time")
local duration = require("@self/duration")

local time = {}

export type Duration = duration.Duration
export type Instant = luteTime.Instant

time.duration = duration

function time.now(): Instant
	return luteTime.now()
end

function time.since(instant: Instant): number
	return luteTime.since(instant)
end

return table.freeze(time)
