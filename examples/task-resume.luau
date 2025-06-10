local task = require("@lute/task")

local c = coroutine.create(function()
	print("hello")
	print(coroutine.yield())
	print("wtf")
end)

task.resume(c)
task.resume(c, "world", "meow for good measure")

local t = coroutine.running()

task.spawn(print, 3, 2, 1)
