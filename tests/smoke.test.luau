local test = require("@std/test")

test.suite("SmokeSuite", function()
	test.case("make_fail", function()
		test.assert.eq(1, 2) -- uncomment to make the test fail
		-- test.assert.eq(1, 1) -- comment to make the test fail
	end)
	test.case("make_pass", function()
		test.assert.eq(1, 1)
	end)
end)

test.case("Passing", function() end)

test.run()
