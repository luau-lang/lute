local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("strcontains_failure_suite", function(suite)
	suite:case("strcontains_error", function(assert)
		assert.strContains("hello world", "goodbye")
	end)
end)

runner.runRegisteredTests()
