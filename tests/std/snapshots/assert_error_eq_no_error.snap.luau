local test = require("@std/test")

test.case("erroreq_error", function(assert)
	assert.throwsWith(function()
		return
	end, "expected message")
end)

test.run()
