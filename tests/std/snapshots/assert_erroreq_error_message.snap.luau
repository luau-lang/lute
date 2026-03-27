local test = require("@std/test")

test.suite("throws_failure_suite", function(suite)
	suite:case("throws_error", function(assert)
		assert.throws(function()
			error("wrong message")
		end, "expected message")
	end)
end)

test.run()
