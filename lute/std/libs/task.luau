--!strict
-- @std/task
-- stdlib for `@lute/task`
-- Provides utilities for creating and managing asynchronous tasks

local lutetask = require("@lute/task")

local taskLib = {}

function taskLib.spawn<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	return lutetask.spawn(routine, ...)
end

function taskLib.defer<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	return lutetask.defer(routine, ...)
end

function taskLib.delay<T..., U...>(dur: number, routine: ((T...) -> U...) | thread, ...: T...): thread
	return lutetask.delay(dur, routine, ...)
end

function taskLib.wait(dur: number?): number
	return lutetask.wait(dur)
end

function taskLib.cancel(thread: thread)
	coroutine.close(thread)
end

return table.freeze(taskLib)
