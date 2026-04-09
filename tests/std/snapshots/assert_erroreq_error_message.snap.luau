local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("throwsWith_failure_suite", function(suite)
	suite:case("throwsWith_error", function(assert)
		assert.throwsWith("expected message", function()
			error("wrong message")
		end)
	end)
end)

runner.runRegisteredTests()
