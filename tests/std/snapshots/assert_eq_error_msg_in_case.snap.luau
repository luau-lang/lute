local test = require("@std/test")

test.case("eq_error", function(assert)
	assert.eq(1, 2)
end)

require("@std/test/runner").runRegisteredTests()
