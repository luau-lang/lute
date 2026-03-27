--!strict
-- @std/task
-- stdlib for `@lute/task`
-- Provides utilities for creating and managing asynchronous tasks

local lutetask = require("@lute/task")

local tasklib = {}

export type Task = {
	success: boolean?,
	result: any,
	co: thread,
}

function tasklib.spawn<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	return lutetask.spawn(routine, ...)
end

function tasklib.defer<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	return lutetask.defer(routine, ...)
end

function tasklib.delay<T..., U...>(dur: number, routine: ((T...) -> U...) | thread, ...: T...): thread
	return lutetask.delay(dur, routine, ...)
end

function tasklib.wait(dur: number?): number
	return lutetask.wait(dur)
end

function tasklib.cancel(thread: thread)
	coroutine.close(thread)
end

function tasklib.create(f, ...): Task
	local data = {}

	data.co = coroutine.create(function(...)
		local success, result = pcall(f, ...)

		data.success = success
		data.result = result
	end)

	coroutine.resume(data.co, ...)
	return data :: Task
end

function tasklib.await(t: Task): any
	if not t.co then
		error(`await: argument 1 is not a task`)
	end

	while t.success == nil do
		lutetask.deferSelf()
	end

	if t.success then
		return t.result
	else
		error(t.result)
	end
end

function tasklib.awaitAll(...: Task): ...unknown
	local tasks = table.pack(...)

	for i, v in ipairs(tasks) do
		if not v.co then
			error(`awaitAll: argument {i} is not a task`)
		end
	end

	local done = false

	while not done do
		done = true
		for _, v in ipairs(tasks) do
			if v.success == nil then
				done = false
				lutetask.deferSelf()
			end
		end
	end

	local results = {}

	for _, v in ipairs(tasks) do
		if v.success then
			table.insert(results, v.result)
		else
			error(v.result)
		end
	end

	return table.unpack(results)
end

return table.freeze(tasklib)
