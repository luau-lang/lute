local test = require("@std/test")

test.suite("erroreq_failure_suite", function(suite)
	suite:case("erroreq_error", function(assert)
		assert.erroreq(function()
			error("wrong message")
		end, "expected message")
	end)
end)

test.run()
