local test = require("@std/test")

test.case("foo", function(assert)
	assert.eq(3, 3)
	assert.eq(6, 1)
end)

test.case("bar", function(assert)
	assert.eq("a", "b")
end)

test.case("baz", function(assert)
	assert.neq("a", "b")
end)

test.suite("MySuite", function(suite)
	suite.case("subsuite", function(assert)
		assert.neq(1, 2)
		assert.eq(1, 2)
	end)
end)

test.run()
