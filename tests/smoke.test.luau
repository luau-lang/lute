local test = require("@std/test")

test.suite("SmokeSuite", function()
	test.case("make_fail", function()
		-- test.assert.eq(1, 2)
		test.assert.eq(1, 1) -- comment this and uncomment above to make the test fail
	end)
	test.case("make_pass", function()
		test.assert.eq(1, 1)
	end)
end)

test.case("Passing", function() end)

test.run()
