local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("buffereq_failure_suite", function(suite)
	suite:case("buffereq_error", function(assert)
		local buf1 = buffer.create(2)
		local buf2 = buffer.create(2)
		buffer.writeu8(buf1, 0, 84)
		buffer.writeu8(buf2, 0, 85)
		assert.eq(buf1, buf2)
	end)
end)

runner.runRegisteredTests()
