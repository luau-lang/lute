local time = {}
local duration = {}
local duration_ops = {}
local instant = {}

function time.now(): Instant
	error("not implemented")
end

function time.since(instant: Instant): number
	error("not implemented")
end

function duration.nanoseconds(nanoseconds: number): Duration
	error("not implemented")
end

function duration.microseconds(microseconds: number): Duration
	error("not implemented")
end

function duration.milliseconds(milliseconds: number): Duration
	error("not implemented")
end

function duration.seconds(seconds: number): Duration
	error("not implemented")
end

function duration.minutes(minutes: number): Duration
	error("not implemented")
end

function duration.hours(hours: number): Duration
	error("not implemented")
end

function duration.days(days: number): Duration
	error("not implemented")
end

function duration.weeks(weeks: number): Duration
	error("not implemented")
end

function instant.elapsed(self: Instant): number
	error("not implemented")
end

function duration_ops.tonanoseconds(self: Duration): number
	error("not implemented")
end

function duration_ops.tomicroseconds(self: Duration): number
	error("not implemented")
end

function duration_ops.tomilliseconds(self: Duration): number
	error("not implemented")
end

function duration_ops.toseconds(self: Duration): number
	error("not implemented")
end

function duration_ops.tominutes(self: Duration): number
	error("not implemented")
end

function duration_ops.tohours(self: Duration): number
	error("not implemented")
end

function duration_ops.todays(self: Duration): number
	error("not implemented")
end

function duration_ops.toweeks(self: Duration): number
	error("not implemented")
end

function duration_ops.subsecnanos(self: Duration): number
	error("not implemented")
end

function duration_ops.subsecmicros(self: Duration): number
	error("not implemented")
end

function duration_ops.subsecmillis(self: Duration): number
	error("not implemented")
end

type Frozen = typeof(table.freeze({}))
export type Duration = setmetatable<Frozen, {
	read __metatable: "The metatable is locked!",
	read __index: typeof(table.freeze(duration_ops)),
	read __add: (Duration, Duration) -> Duration,
	read __sub: (Duration, Duration) -> Duration,
	read __eq: (Duration, Duration) -> boolean,
	read __lt: (Duration, Duration) -> boolean,
	read __le: (Duration, Duration) -> boolean,
}>

export type Instant = setmetatable<Frozen, {
	read __metatable: "The metatable is locked!",
	read __index: typeof(table.freeze(instant)),
	read __sub: (Instant, Instant) -> Duration,
}>

time.duration = duration
return time
