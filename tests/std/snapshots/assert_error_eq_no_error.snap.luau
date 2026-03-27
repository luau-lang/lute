local test = require("@std/test")

test.case("throws_error", function(assert)
	assert.throws(function()
		return
	end, "expected message")
end)

test.run()
