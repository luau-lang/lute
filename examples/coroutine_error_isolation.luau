local task = require("@lute/task")

local function loop()
	while true do
		task.defer()

		-- It may be useful to remove this print because it gets spammed, or implement another way
		-- in which you can determinatively tell whether or not the thread is still active despite
		-- an error in the other
		print("hi")
	end
end

local function otherloop()
	while true do
		task.defer()

		if math.random(1, 2) == 1 then
			error("oops")
		end
	end
end

coroutine.resume(coroutine.create(loop))
coroutine.resume(coroutine.create(otherloop))
