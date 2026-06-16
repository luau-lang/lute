local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("never_strcontains_failure_suite", function(suite)
	suite:case("never_strcontains_error", function(assert)
		assert.never.strContains("hello world", "world")
	end)
end)

runner.runRegisteredTests()
