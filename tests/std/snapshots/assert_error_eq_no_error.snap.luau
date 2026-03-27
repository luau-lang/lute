local test = require("@std/test")

test.case("throwsWithError", function(assert)
	assert.throwsWith(function()
		return
	end, "expected message")
end)

test.run()
