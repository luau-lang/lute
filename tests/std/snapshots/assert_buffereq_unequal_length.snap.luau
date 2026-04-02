local test = require("@std/test")

test.case("buffereq_error", function(assert)
	local buf1 = buffer.create(1)
	local buf2 = buffer.create(2)
	assert.eq(buf1, buf2)
end)

require("@std/test/runner").runRegisteredTests()
