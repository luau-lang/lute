local test = require("@std/test")

test.case("neq_error", function(assert)
	assert.neq(1, 1)
end)

test.run()
