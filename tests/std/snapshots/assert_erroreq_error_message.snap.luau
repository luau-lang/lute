local test = require("@std/test")

test.suite("throwsWith_failure_suite", function(suite)
	suite:case("throwsWith_error", function(assert)
		assert.throwsWith(function()
			error("wrong message")
		end, "expected message")
	end)
end)

test.run()
