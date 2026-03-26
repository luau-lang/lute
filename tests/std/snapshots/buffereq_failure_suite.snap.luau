local test = require("@std/test")

test.suite("buffereq_failure_suite", function(suite)
	suite:case("buffereq_error", function(assert)
		local buf1 = buffer.create(2)
		local buf2 = buffer.create(2)
		buffer.writeu8(buf1, 0, 84)
		buffer.writeu8(buf2, 0, 85)
		assert.buffereq(buf1, buf2)
		assert.eq(buf1, buf2)
	end)
end)

test.run()
