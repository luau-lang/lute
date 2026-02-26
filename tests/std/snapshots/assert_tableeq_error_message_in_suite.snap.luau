local test = require("@std/test")

test.suite("tableeq_failure_suite", function(suite)
	suite:case("tableeq_error", function(assert)
		assert.tableeq({ a = 1 }, { a = 2 })
	end)
end)

test.run()
