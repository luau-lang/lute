--!strict
-- @std/task
-- stdlib for `@lute/task`
-- Provides utilities for creating and managing asynchronous tasks

local lutetask = require("@lute/task")

local task = {}

--- Schedules `routine` to run immediately on the next resumption cycle, passing any additional arguments to it. Returns the thread.
function task.spawn<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	return lutetask.spawn(routine, ...)
end

--- Schedules `routine` to run after the current thread yields, passing any additional arguments to it. Returns the thread.
function task.defer<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	return lutetask.defer(routine, ...)
end

--- Schedules `routine` to run after `dur` seconds, passing any additional arguments to it. Returns the thread.
function task.delay<T..., U...>(dur: number, routine: ((T...) -> U...) | thread, ...: T...): thread
	return lutetask.delay(dur, routine, ...)
end

--- Yields the current thread for `dur` seconds (or until the next cycle if `dur` is omitted). Returns the actual time waited.
function task.wait(dur: number?): number
	return lutetask.wait(dur)
end

--- Cancels `thread`, preventing it from being resumed again.
function task.cancel(thread: thread)
	coroutine.close(thread)
end

return table.freeze(task)
