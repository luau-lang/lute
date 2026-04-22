local test = require("@std/test")
local runner = require("@std/test/runner")

test.case("tableeq_error", function(assert)
	assert.eq({ a = 1 }, { a = 2 })
end)

runner.runRegisteredTests()
