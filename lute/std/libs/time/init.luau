--!strict
-- @std/time
-- Provides utility functions for time

local duration = require("@self/duration")
local time = {}

export type duration = duration.duration

time.duration = duration

return table.freeze(time)
