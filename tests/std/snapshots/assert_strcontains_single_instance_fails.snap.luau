local test = require("@std/test")

test.suite("strcontains_failure_suite", function(suite)
	suite:case("strcontains_error", function(assert)
		assert.strcontains("hello world", "goodbye")
	end)
end)

test.run()
