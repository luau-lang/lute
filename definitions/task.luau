-- lute-lint-global-ignore(unused_variable)
local time = require("./time")

local task = {}

function task.spawn<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	error("unimplemented")
end

function task.defer<T..., U...>(routine: ((T...) -> U...) | thread, ...: T...): thread
	error("unimplemented")
end

function task.resume(thread: thread): thread
	error("unimplemented")
end

function task.deferSelf()
	error("unimplemented")
end

function task.wait(dur: (number | time.Duration)?): number
	error("unimplemented")
end

function task.delay<T..., U...>(dur: number | time.Duration, routine: thread | ((T...) -> U...), ...: T...): thread
	error("unimplemented")
end

return task
