local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("never_neq_failure_suite", function(suite)
	suite:case("never_neq_error", function(assert)
		assert.never.neq(1, 2)
	end)
end)

runner.runRegisteredTests()
