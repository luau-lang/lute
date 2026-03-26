local test = require("@std/test")

test.case("strcontains_error", function(assert)
	assert.strcontains("hello world", "goodbye", -1)
end)

test.run()
