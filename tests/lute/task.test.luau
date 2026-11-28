local test = require("@std/test")
local task = require("@lute/task")

test.suite("LuteTaskSuite", function(suite)
	suite:case("simpleTaskWait", function(assert)
		local startTime = os.clock()
		task.wait(0.5)
		local endTime = os.clock()

		-- task.wait(0.5) actually waits ~0.48 seconds :)
		assert.that(math.ceil(endTime - startTime) >= 0.5)
	end)

	suite:case("taskWaitInLoop", function(assert)
		local startTime = os.clock()
		local elapsed = 0
		while elapsed < 0.5 do
			task.wait(0.1)
			elapsed = os.clock() - startTime
		end
		local endTime = os.clock()

		assert.that(endTime - startTime >= 0.5)
	end)

	suite:case("taskSpawn0ArgsErrors", function(assert)
		assert.throws(function()
			(task.spawn :: any)()
		end)
	end)

	suite:case("taskDefer0ArgsErrors", function(assert)
		assert.throws(function()
			(task.defer :: any)()
		end)
	end)

	suite:case("taskDelayReturnsScheduledThreadsAndPassesArguments", function(assert)
		local called: { [string]: boolean } = {}
		local function record(value: string)
			called[value] = true
		end

		local newThread = task.delay(0, record, "function")
		local existingThread = coroutine.create(record)
		local returnedThread = task.delay(0, existingThread, "thread")

		assert.eq(typeof(newThread), "thread")
		assert.eq(returnedThread, existingThread)
		task.wait(0.01)
		assert.eq(called["function"], true)
		assert.eq(called["thread"], true)
	end)

	suite:case("taskSpawnFunctionNoArgsCoroutineStatus", function(assert)
		local thread = task.spawn(function()
			task.wait(2)
		end)

		local status = coroutine.status(thread)
		assert.eq(status, "suspended")
		coroutine.close(thread)
	end)

	-- task.spawn with thread, 0 args
	suite:case("taskSpawnThreadNoArgsCoroutineStatus", function(assert)
		local co = coroutine.create(function()
			task.wait(2)
		end)
		local thread = task.spawn(co)

		local status = coroutine.status(thread)
		assert.eq(status, "suspended")
		coroutine.close(thread)
	end)

	-- task.spawn with function, >0 args
	suite:case("taskSpawnFunctionWithArgsCoroutineStatus", function(assert)
		local thread = task.spawn(function(_a, _b, _c)
			task.wait(2)
		end, "hello", "world", "boom")

		local status = coroutine.status(thread)
		assert.eq(status, "suspended")
		coroutine.close(thread)
	end)

	-- task.spawn with thread, >0 args
	suite:case("taskSpawnThreadWithArgsCoroutineStatus", function(assert)
		local co = coroutine.create(function(_a, _b, _c)
			task.wait(2)
		end)
		local thread = task.spawn(co, "hello", "world", "boom")

		local status = coroutine.status(thread)
		assert.eq(status, "suspended")
		coroutine.close(thread)
	end)

	-- task.defer with function, 0 args
	suite:case("taskDeferFunctionNoArgsCoroutineStatus", function(assert)
		local thread = task.defer(function()
			task.wait(2)
		end)

		local status = coroutine.status(thread)
		assert.eq(status, "suspended")
		coroutine.close(thread)
	end)

	-- task.defer with thread, 0 args
	suite:case("taskDeferThreadNoArgsCoroutineStatus", function(assert)
		local co = coroutine.create(function()
			task.wait(2)
		end)
		local thread = task.defer(co)

		local status = coroutine.status(thread)
		assert.eq(status, "suspended")
		coroutine.close(thread)
	end)

	-- task.defer with function, >0 args
	suite:case("taskDeferFunctionWithArgsCoroutineStatus", function(assert)
		local thread = task.defer(function(_a, _b, _c)
			task.wait(2)
		end, "hello", "world", "boom")

		local status = coroutine.status(thread)
		assert.eq(status, "suspended")
		coroutine.close(thread)
	end)

	-- task.defer with thread, >0 args
	suite:case("taskDeferThreadWithArgsCoroutineStatus", function(assert)
		local co = coroutine.create(function(_a, _b, _c)
			task.wait(2)
		end)
		local thread = task.defer(co, "hello", "world", "boom")

		local status = coroutine.status(thread)
		assert.eq(status, "suspended")
		coroutine.close(thread)
	end)

	-- task.resume with thread, 0 args
	suite:case("taskResumeThreadNoArgsCoroutineStatus", function(assert)
		local co = coroutine.create(function()
			task.wait(2)
		end)
		local thread = task.resume(co)

		local status = coroutine.status(thread)
		assert.eq(status, "suspended")
		coroutine.close(thread)
	end)

	-- task.resume with thread, >0 args
	suite:case("taskResumeThreadWithArgsCoroutineStatus", function(assert)
		local co = coroutine.create(function(_a, _b, _c)
			task.wait(2)
		end)
		local thread = task.resume(co, "hello", "world", "boom")

		local status = coroutine.status(thread)
		assert.eq(status, "suspended")
		coroutine.close(thread)
	end)
end)
