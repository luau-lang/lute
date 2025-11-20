local stringext = require("@std/stringext")
local test = require("@std/test")

test.suite("StringExt", function(suite)
	suite:case("hasprefix_and_hassuffix", function(assert)
		assert.eq(stringext.hasprefix("hello", "he"), true)
		assert.eq(stringext.hasprefix("hi", "hello"), false)

		assert.eq(stringext.hassuffix("foobar", "bar"), true)
		assert.eq(stringext.hassuffix("foo", "foobar"), false)
	end)

	suite:case("removeprefix_and_removesuffix", function(assert)
		assert.eq(stringext.removeprefix("hello", "he"), "llo")
		assert.eq(stringext.removeprefix("hello", "nope"), "hello")

		assert.eq(stringext.removesuffix("foobar", "bar"), "foo")
		assert.eq(stringext.removesuffix("foobar", "nope"), "foobar")
	end)

	suite:case("trim", function(assert)
		assert.eq(stringext.trim("  a b  "), "a b")
		assert.eq(stringext.trim("\n\thi\n"), "hi")
		assert.eq(stringext.trim(""), "")
		assert.eq(stringext.trim("   "), "")
	end)
end)

test.run()
