-- lute-lint-global-ignore(unused_variable)
local time = {}

local duration_ops = {}
local instant = {}

--- Returns the current time as an `Instant`.
function time.now(): Instant
	error("not implemented")
end

--- Returns the number of seconds elapsed since `instant`.
function time.since(instant: Instant): number
	error("not implemented")
end

time.duration = {}

--- Creates a `Duration` from `seconds` and a fractional `subsecnanos` nanosecond component.
function time.duration.create(seconds: number, subsecnanos: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of nanoseconds.
function time.duration.nanoseconds(nanoseconds: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of microseconds.
function time.duration.microseconds(microseconds: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of milliseconds.
function time.duration.milliseconds(milliseconds: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of seconds.
function time.duration.seconds(seconds: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of minutes.
function time.duration.minutes(minutes: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of hours.
function time.duration.hours(hours: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of days.
function time.duration.days(days: number): Duration
	error("not implemented")
end

--- Creates a `Duration` from a number of weeks.
function time.duration.weeks(weeks: number): Duration
	error("not implemented")
end

function instant.elapsed(self: Instant): number
	error("not implemented")
end

function duration_ops.toNanoseconds(self: Duration): number
	error("not implemented")
end

function duration_ops.toMicroseconds(self: Duration): number
	error("not implemented")
end

function duration_ops.toMilliseconds(self: Duration): number
	error("not implemented")
end

function duration_ops.toSeconds(self: Duration): number
	error("not implemented")
end

function duration_ops.toMinutes(self: Duration): number
	error("not implemented")
end

function duration_ops.toHours(self: Duration): number
	error("not implemented")
end

function duration_ops.toDays(self: Duration): number
	error("not implemented")
end

function duration_ops.toWeeks(self: Duration): number
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
--- A time duration with nanosecond precision. Supports arithmetic via `+`, `-`, `*`, `/`, and comparison operators.
export type Duration = setmetatable<Frozen, {
	read __metatable: "The metatable is locked!",
	read __index: typeof(table.freeze(duration_ops)),
	read __add: (Duration, Duration) -> Duration,
	read __sub: (Duration, Duration) -> Duration,
	read __mul: (Duration, number) -> Duration,
	read __div: (Duration, number) -> Duration,
	read __eq: (Duration, Duration) -> boolean,
	read __lt: (Duration, Duration) -> boolean,
	read __le: (Duration, Duration) -> boolean,
}>

--- A point in time with nanosecond precision. Can be subtracted from another `Instant` to produce a `Duration`.
export type Instant = setmetatable<Frozen, {
	read __metatable: "The metatable is locked!",
	read __index: typeof(table.freeze(instant)),
	read __sub: (Instant, Instant) -> Duration,
	read __eq: (Instant, Instant) -> boolean,
	read __lt: (Instant, Instant) -> boolean,
	read __le: (Instant, Instant) -> boolean,
}>

return time
