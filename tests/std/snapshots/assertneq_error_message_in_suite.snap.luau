local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("neq_failure_suite", function(suite)
	suite:case("neq_error", function(assert)
		assert.neq(1, 1)
	end)
end)

runner.runRegisteredTests()
