local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("tableeq_failure_suite", function(suite)
	suite:case("tableeq_error", function(assert)
		assert.eq({ a = 1 }, { a = 2 })
	end)
end)

runner.runRegisteredTests()
