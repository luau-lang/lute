local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("never_that_failure_suite", function(suite)
	suite:case("never_that_error", function(assert)
		assert.never.that(true)
	end)
end)

runner.runRegisteredTests()
