local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execpath())

local expected = [[Anonymous:
	Passing
ExampleSuite:
	should pass
SmokeSuite:
	make_fail
	make_pass
]]

test.suite("LuteTestCommand", function(suite)
	suite:case("lute test help message", function(assert)
		-- Run lute test with -h flag
		local result = process.run({ lutePath, "test", "-h" })

		-- Check that it exits successfully and prints help
		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, "Usage:")
	end)

	suite:case("lute test runs tests in discovery folder", function(assert)
		-- Run lute test on tests/cli/discovery folder
		local result = process.run({ lutePath, "test", "tests/cli/discovery" })

		-- Check that it runs tests and succeeds
		assert.eq(result.exitcode, 0)
	end)

	suite:case("lute_test_discovery_custom_directory", function(assert)
		-- Run lute test with custom directory path
		local result = process.run({ lutePath, "test", "--list", "tests/cli/discovery" })

		-- Check that it discovers test files (.test.luau and .spec.luau)
		assert.eq(result.exitcode, 0)
		assert.eq(expected, result.stdout)
	end)

	suite:case("filter_by_suite_name", function(assert)
		-- Run lute test with --suite flag
		local result = process.run({ lutePath, "test", "-s", "SmokeSuite", "tests/cli/discovery" })

		-- Check that it runs only tests in SmokeSuite
		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("Total:  2", 1, true), nil)
		assert.neq(result.stdout:find("Passed: 2", 1, true), nil)
	end)

	suite:case("lute test filters by case name", function(assert)
		-- Run lute test with --case flag
		local result = process.run({ lutePath, "test", "--case", "make_pass", "tests/cli/discovery" })

		-- Check that it runs only tests named make_pass
		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("Total:  1", 1, true), nil)
		assert.neq(result.stdout:find("Passed: 1", 1, true), nil)
	end)

	suite:case("lute test filters by suite and case name", function(assert)
		-- Run lute test with both --suite and --case flags
		local result = process.run({ lutePath, "test", "-s", "SmokeSuite", "-c", "make_fail", "tests/cli/discovery" })

		-- Check that it runs only make_fail in SmokeSuite
		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("Total:  1", 1, true), nil)
		assert.neq(result.stdout:find("Passed: 1", 1, true), nil)
	end)
end)

test.run()
