local process = require("@std/process")
local system = require("@std/system")
local task = require("@std/task")
local test = require("@std/test")

test.suite("SignalSuite", function(suite)
	-- the type of `process.onSignal` restricts unknown signals at compile-time,
	-- but we cast anyway to verify the runtime checks are in place.
	suite:case("unknownSignalThrows", function(assert)
		assert.throwsWith("unknown signal: SIGFOO", function()
			process.onSignal("SIGFOO" :: any, function() end)
		end)
	end)

	-- the type of `process.onSignal` restricts these cases at compile-time,
	-- but we cast anyway to verify the runtime checks are in place.
	suite:case("blockedSignalsThrow", function(assert)
		assert.throwsWith("SIGKILL cannot be handled", function()
			process.onSignal("SIGKILL" :: any, function() end)
		end)
		assert.throwsWith("SIGCHLD is reserved by the runtime", function()
			process.onSignal("SIGCHLD" :: any, function() end)
		end)
		assert.throwsWith("SIGSEGV is a synchronous hardware signal and cannot be safely handled", function()
			process.onSignal("SIGSEGV" :: any, function() end)
		end)
	end)

	suite:case("handleCloseIsIdempotent", function(_assert)
		local handle = process.onSignal("SIGTERM", function() end)
		handle:close()
		handle:close()
	end)

	-- Signal delivery tests use the `kill` commands to send signals to the current process
	-- Through a combination of both what libuv supports, what Windows supports, what's safe,
	-- and what the testing environment actually allows, we can only reliably test this behavior
	-- on Unix platforms, or without the use of address sanitizers (since ASAN appears to leverage
	-- both SIGUSR1 and SIGUSR2). We may revisit this at some point for better Windows converage.
	if system.unix then
		suite:case("signalIsDeliveredToHandler", function(assert)
			local received = false

			local handle = process.onSignal("SIGTERM", function()
				received = true
			end)

			local pid = process.pid()
			process.run({ "kill", "-TERM", tostring(pid) })
			task.wait(0.1)

			handle:close()
			assert.that(received)
		end)

		suite:case("multipleHandlersFire", function(assert)
			local count = 0

			local h1 = process.onSignal("SIGTERM", function()
				count += 1
			end)
			local h2 = process.onSignal("SIGTERM", function()
				count += 1
			end)

			local pid = process.pid()
			process.run({ "kill", "-TERM", tostring(pid) })
			task.wait(0.1)

			h1:close()
			h2:close()
			assert.eq(count, 2)
		end)

		suite:case("closedHandlerDoesNotFire", function(assert)
			local received = false

			local handle = process.onSignal("SIGWINCH", function()
				received = true
			end)
			handle:close()

			-- SIGWINCH's default action is discard, so sending it with no active
			-- handler does not terminate the process.
			local pid = process.pid()
			process.run({ "kill", "-WINCH", tostring(pid) })
			task.wait(0.1)

			assert.eq(received, false)
		end)
	end
end)
