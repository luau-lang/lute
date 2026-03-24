local stringext = require("@std/stringext")
local test = require("@std/test")

test.suite("StringExt", function(suite)
	suite:case("hasprefixAndHassuffix", function(assert)
		assert.truthy(stringext.hasprefix("hello", "he"))
		assert.eq(stringext.hasprefix("hi", "hello"), false)

		assert.truthy(stringext.hassuffix("foobar", "bar"))
		assert.eq(stringext.hassuffix("foo", "foobar"), false)
	end)

	suite:case("removeprefixAndRemovesuffix", function(assert)
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

	suite:case("count", function(assert)
		assert.eq(stringext.count("hello world", "o"), 2)
		assert.eq(stringext.count("hello world", "l", 4), 2) -- from position 4 to end
		assert.eq(stringext.count("hello world", "l", nil, 5), 2) -- from start to position 5
		assert.eq(stringext.count("hello world", "l", 4, 9), 1) -- from position 4 to position 9
		assert.eq(stringext.count("aaaaaa", "aa"), 3) -- overlapping patterns
		assert.eq(stringext.count("no matches here", "z"), 0)
		assert.eq(stringext.count("hello world", "%s"), 1) -- patterns supported too
		assert.eq(stringext.count("hello world", "[hw]"), 2) -- count h and w
	end)
end)
