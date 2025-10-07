local test = require("@std/test")
local check = test.assert
test.case("foo", function()
	check.eq(3, 3)
	check.eq(6, 1)
end)

test.case("bar", function()
	check.eq("a", "b")
end)

test.case("baz", function()
	check.neq("a", "b")
end)

test.suite("MySuite", function()
	test.case("subcase", function()
		check.eq(5 * 5, 3)
	end)
end)

test.run()
