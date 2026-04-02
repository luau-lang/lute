local test = require("@std/test")
local runner = require("@std/test/runner")

test.case("eq_error", function(assert)
	assert.eq(1, 2)
end)

runner.runRegisteredTests()
