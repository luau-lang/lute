local time = require("./time")

local task = {}

function task.defer()
	error("unimplemented")
end

function task.wait(dur: (number | time.Duration)?)
	error("unimplemented")
end

function task.spawn<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...)
	error("unimplemented")
end

function task.resume(thread: thread)
	error("unimplemented")
end

return task
