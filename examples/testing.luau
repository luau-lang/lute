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
	-- beforeall runs once before all tests in the suite
	suite:beforeall(function()
		print("Setting up MySuite - runs once before all tests")
	end)

	-- beforeeach runs before each individual test
	suite:beforeeach(function()
		print("Running before each test")
	end)

	-- aftereach runs after each individual test
	suite:aftereach(function()
		print("Cleaning up after each test")
	end)

	-- afterall runs once after all tests in the suite
	suite:afterall(function()
		print("Tearing down MySuite - runs once after all tests")
	end)

	suite:case("subsuite", function(assert)
		assert.neq(1, 2)
		assert.eq(1, 2)
	end)

	suite:case("another_test", function(assert)
		assert.eq(1, 1)
	end)

	-- Example of table_eq assertion - demonstrates error reporting
	suite:case("table_comparison", function(assert)
		local table1 = { a = 1, b = { c = 2, d = 3 } }
		local table2 = { a = 1, b = { c = 2, d = 3 } }
		assert.tableeq(table1, table2)
		assert.tableeq(table1, { a = 1 })
	end)

	suite:case("expect_error", function(assert)
		local function foo(v: boolean)
			if v then error("error") end
		end
		assert.throwserror(function() -- demonstrates success (callback throws err)
			foo(true)
		end)
		assert.throwserror(function() -- demonstrates failure (callback doesn't throw)
			foo(false)
		end)
	end)
end)

test.run()
