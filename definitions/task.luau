-- lute-lint-global-ignore(unused_variable)
local time = require("./time")

local task = {}

--- Schedules `routine` to run immediately on the next resumption cycle, passing any additional arguments to it. Returns the thread.
function task.spawn<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	error("unimplemented")
end

--- Schedules `routine` to run after the current thread yields, passing any additional arguments to it. Returns the thread.
function task.defer<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	error("unimplemented")
end

--- Resumes `thread`, running it until it yields or completes. Returns the thread.
function task.resume(thread: thread): thread
	error("unimplemented")
end

--- Yields the current thread and re-schedules it for the next resumption cycle.
function task.deferSelf()
	error("unimplemented")
end

--- Yields the current thread for `dur` seconds (or until the next cycle if `dur` is omitted). Returns the actual time waited.
function task.wait(dur: (number | time.Duration)?): number
	error("unimplemented")
end

--- Schedules `routine` to run after `dur` seconds, passing any additional arguments to it. Returns the thread.
function task.delay<T..., U...>(dur: number | time.Duration, routine: thread | ((T...) -> U...), ...: T...): thread
	error("unimplemented")
end

return task
