local test = require("@std/test")
local runner = require("@std/test/runner")

test.case("throwsWithError", function(assert)
	assert.throwsWith("expected message", function()
		return
	end)
end)

runner.runRegisteredTests()
