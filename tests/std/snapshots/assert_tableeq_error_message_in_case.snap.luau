local test = require("@std/test")

test.case("tableeq_error", function(assert)
	assert.tableeq({ a = 1 }, { a = 2 })
	assert.eq({ a = 1 }, { a = 2 })
end)

test.run()
