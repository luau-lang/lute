local test = require("@std/test")

test.suite("ExampleSuite", function(suite)
	suite:case("shouldPass", function(assert)
		assert.eq(2 + 2, 4)
	end)
end)
