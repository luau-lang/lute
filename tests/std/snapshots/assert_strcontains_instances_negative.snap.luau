local test = require("@std/test")
local runner = require("@std/test/runner")

test.case("strcontains_error", function(assert)
	assert.strContains("hello world", "goodbye", -1)
end)

runner.runRegisteredTests()
