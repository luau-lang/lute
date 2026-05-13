local process = require("@std/process")
local task = require("@std/task")
local test = require("@std/test")

test.suite("SignalSuite", function(suite)
	suite:case("unknownSignalThrows", function(assert)
		assert.throwsWith("unknown signal: SIGFOO", function()
			process.onSignal("SIGFOO", function() end)
		end)
	end)

	suite:case("blockedSignalsThrow", function(assert)
		assert.throwsWith("SIGKILL cannot be handled", function()
			process.onSignal("SIGKILL", function() end)
		end)
		assert.throwsWith("SIGCHLD is reserved by the runtime", function()
			process.onSignal("SIGCHLD", function() end)
		end)
		assert.throwsWith("SIGSEGV is a synchronous hardware signal and cannot be safely handled", function()
			process.onSignal("SIGSEGV", function() end)
		end)
	end)

	suite:case("handleCloseIsIdempotent", function(assert)
		local handle = process.onSignal("SIGTERM", function() end)
		handle:close()
		handle:close()
	end)

	suite:case("signalIsDeliveredToHandler", function(assert)
		local received = false

		local handle = process.onSignal("SIGUSR1", function()
			received = true
		end)

		local pid = process.pid()
		process.run({ "kill", "-USR1", tostring(pid) })
		task.wait(0.1)

		handle:close()
		assert.that(received)
	end)

	suite:case("multipleHandlersFire", function(assert)
		local count = 0

		local h1 = process.onSignal("SIGUSR2", function()
			count += 1
		end)
		local h2 = process.onSignal("SIGUSR2", function()
			count += 1
		end)

		local pid = process.pid()
		process.run({ "kill", "-USR2", tostring(pid) })
		task.wait(0.1)

		h1:close()
		h2:close()
		assert.eq(count, 2)
	end)

	suite:case("closedHandlerDoesNotFire", function(assert)
		local received = false

		local handle = process.onSignal("SIGUSR1", function()
			received = true
		end)
		handle:close()

		local pid = process.pid()
		process.run({ "kill", "-USR1", tostring(pid) })
		task.wait(0.1)

		assert.eq(received, false)
	end)
end)
