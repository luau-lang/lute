--!strict
-- @std/task
-- stdlib for `@lute/task`
-- Provides utilities for creating and managing asynchronous tasks

local task = require("@lute/task")

local tasklib = {}

export type task = {
	success: boolean?,
	result: any,
	co: thread,
}

function tasklib.create(f, ...): task
	local data = {}

	data.co = coroutine.create(function(...)
		local success, result = pcall(f, ...)

		data.success = success
		data.result = result
	end)

	coroutine.resume(data.co, ...)
	return data :: task
end

function tasklib.await(t: task)
	if not t.co then
		error(`await: argument 1 is not a task`)
	end

	while t.success == nil do
		task.defer()
	end

	if t.success then
		return t.result
	else
		error(t.result)
	end
end

function tasklib.awaitall(...: task)
	local tasks = table.pack(...)

	for i, v in ipairs(tasks) do
		if not v.co then
			error(`awaitAll: argument {i} is not a task`)
		end
	end

	local done = false

	while not done do
		done = true
		for _, v in tasks do
			if v.success == nil then
				done = false
				task.defer()
			end
		end
	end

	local results = {}

	for _, v in tasks do
		if v.success then
			table.insert(results, v.result)
		else
			error(v.result)
		end
	end

	return table.unpack(results)
end

return table.freeze(tasklib)
