local time = require("./time")

local task = {}

function task.defer()
	error("unimplemented")
end

function task.wait(dur: (number | time.Duration)?): number
	error("unimplemented")
end

function task.spawn<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	error("unimplemented")
end

function task.resume(thread: thread): thread
	error("unimplemented")
end

function task.delay<T..., U...>(dur: number | time.Duration, routine: (T...) -> U..., ...: T...): thread
	error("unimplemented")
end

return task
