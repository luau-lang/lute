local test = require("@std/test")

test.suite("SmokeSuite", function(suite)
	suite:case("make_fail", function(assert)
		-- assert.eq(1, 2)
		assert.eq(1, 1) -- comment this and uncomment above to make the test fail
	end)
	suite:case("make_pass", function(assert)
		assert.eq(1, 1)
	end)
end)

test.case("Passing", function(assert) end)

test.run()
