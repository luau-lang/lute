local test = require("@std/test")
local task = require("@lute/task")

test.suite("LuteTaskSuite", function(suite)
	suite:case("simple_task_wait", function(assert)
		local startTime = os.clock()
		task.wait(0.5)
		local endTime = os.clock()

		print("Elapsed time: ", endTime - startTime)

		-- task.wait(0.5) actually waits ~0.48 seconds :)
		assert.eq(math.ceil(endTime - startTime) >= 0.5, true)
	end)

	suite:case("task_wait_in_loop", function(assert)
		local startTime = os.clock()
		local elapsed = 0
		while elapsed < 0.5 do
			task.wait(0.1)
			elapsed = os.clock() - startTime
		end
		local endTime = os.clock()

		assert.eq(endTime - startTime >= 0.5, true)
	end)
end)

test.run()
