local task = require("@lute/task")

local c = coroutine.create(function()
	print("hi")
	coroutine.yield()
	print("hi2")
	error("hello world")
end)

task.resume(c)
task.resume(c)
