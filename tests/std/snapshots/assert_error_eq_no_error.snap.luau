local test = require("@std/test")

test.case("throwsWithError", function(assert)
	assert.throwsWith("expected message", function()
		return
	end)
end)

test.run()
