local test = require("@std/test")

test.suite("eq_failure_suite", function(suite)
	suite:case("eq_error", function(assert)
		assert.eq(1, 2)
	end)
end)

test.run()
