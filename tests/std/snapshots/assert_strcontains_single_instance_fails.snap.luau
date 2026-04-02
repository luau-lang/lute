local test = require("@std/test")

test.suite("strcontains_failure_suite", function(suite)
	suite:case("strcontains_error", function(assert)
		assert.strContains("hello world", "goodbye")
	end)
end)

require("@std/test/runner").runRegisteredTests()
