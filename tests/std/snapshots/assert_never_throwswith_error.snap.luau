local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("never_throwswith_failure_suite", function(suite)
	suite:case("never_throwswith_error", function(assert)
		assert.never.throwsWith("expected message", function()
			error("expected message")
		end)
	end)
end)

runner.runRegisteredTests()
