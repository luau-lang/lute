local test = require("@std/test")

test.suite("ExampleSuite", function(suite)
	suite:case("should pass", function(assert)
		assert.eq(2 + 2, 4)
	end)
end)

test.run()
