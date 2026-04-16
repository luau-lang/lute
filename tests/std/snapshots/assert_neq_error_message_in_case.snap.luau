local test = require("@std/test")
local runner = require("@std/test/runner")

test.case("neq_error", function(assert)
	assert.neq(1, 1)
end)

runner.runRegisteredTests()
