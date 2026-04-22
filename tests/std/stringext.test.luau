local stringExt = require("@std/stringext")
local test = require("@std/test")

test.suite("StringExt", function(suite)
	suite:case("hasprefixAndHasSuffix", function(assert)
		assert.that(stringExt.hasPrefix("hello", "he"))
		assert.eq(stringExt.hasPrefix("hi", "hello"), false)

		assert.that(stringExt.hasSuffix("foobar", "bar"))
		assert.eq(stringExt.hasSuffix("foo", "foobar"), false)
	end)

	suite:case("removePrefixAndRemovesuffix", function(assert)
		assert.eq(stringExt.removePrefix("hello", "he"), "llo")
		assert.eq(stringExt.removePrefix("hello", "nope"), "hello")

		assert.eq(stringExt.removeSuffix("foobar", "bar"), "foo")
		assert.eq(stringExt.removeSuffix("foobar", "nope"), "foobar")
	end)

	suite:case("trim", function(assert)
		assert.eq(stringExt.trim("  a b  "), "a b")
		assert.eq(stringExt.trim("\n\thi\n"), "hi")
		assert.eq(stringExt.trim(""), "")
		assert.eq(stringExt.trim("   "), "")
	end)

	suite:case("count", function(assert)
		assert.eq(stringExt.count("hello world", "o"), 2)
		assert.eq(stringExt.count("hello world", "l", 4), 2) -- from position 4 to end
		assert.eq(stringExt.count("hello world", "l", nil, 5), 2) -- from start to position 5
		assert.eq(stringExt.count("hello world", "l", 4, 9), 1) -- from position 4 to position 9
		assert.eq(stringExt.count("aaaaaa", "aa"), 3) -- overlapping patterns
		assert.eq(stringExt.count("no matches here", "z"), 0)
		assert.eq(stringExt.count("hello world", "%s"), 1) -- patterns supported too
		assert.eq(stringExt.count("hello world", "[hw]"), 2) -- count h and w
	end)
end)
