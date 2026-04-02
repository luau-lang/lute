local test = require("@std/test")

test.suite("throwsWith_failure_suite", function(suite)
	suite:case("throwsWith_error", function(assert)
		assert.throwsWith("expected message", function()
			error("wrong message")
		end)
	end)
end)

require("@std/test/runner").runRegisteredTests()
