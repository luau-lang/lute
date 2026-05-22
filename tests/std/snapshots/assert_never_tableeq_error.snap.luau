local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("never_tableeq_failure_suite", function(suite)
	suite:case("never_tableeq_error", function(assert)
		assert.never.eq({ a = 1 }, { a = 1 })
	end)
end)

runner.runRegisteredTests()
