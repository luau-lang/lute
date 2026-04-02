local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("eq_failure_suite", function(suite)
	suite:case("eq_error", function(assert)
		assert.eq(1, 2)
	end)
end)

runner.runRegisteredTests()
