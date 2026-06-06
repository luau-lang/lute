local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("never_eq_failure_suite", function(suite)
	suite:case("never_eq_error", function(assert)
		assert.never.eq(1, 1)
	end)
end)

runner.runRegisteredTests()
