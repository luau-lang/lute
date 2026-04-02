local task = require("@lute/task")

local c = coroutine.create(function()
	print("hello")
	-- We don't know what subsequent calls to coroutine.yield produce.
	print(coroutine.yield() :: any)
	print("wtf")
end)

task.resume(c)
task.resume(c, "world", "meow for good measure")

local _ = coroutine.running()

task.spawn(print, 3, 2, 1)
