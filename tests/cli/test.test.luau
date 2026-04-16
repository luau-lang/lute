local path = require("@std/path")
local process = require("@std/process")
local test = require("@std/test")

local lutePath = path.format(process.execPath())

local expected = [[Anonymous:
	passing
ExampleSuite:
	shouldPass
SmokeSuite:
	makeFail
	makePass
]]

test.suite("LuteTestCommand", function(suite)
	suite:case("luteTestHelpMessage", function(assert)
		-- Run lute test with -h flag
		local result = process.run({ lutePath, "test", "-h" })

		-- Check that it exits successfully and prints help
		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Usage:")
	end)

	suite:case("luteTestRunsTestsInDiscoveryFolder", function(assert)
		-- Run lute test on tests/cli/discovery folder
		local result = process.run({ lutePath, "test", "tests/cli/discovery" })

		-- Check that it runs tests and succeeds
		assert.eq(result.exitcode, 0)
	end)

	suite:case("luteTestDiscoveryCustomDirectory", function(assert)
		-- Run lute test with custom directory path
		local result = process.run({ lutePath, "test", "--list", "tests/cli/discovery" })

		-- Check that it discovers test files (.test.luau and .spec.luau)
		assert.eq(result.exitcode, 0)
		assert.eq(expected, result.stdout)
	end)

	suite:case("filterBySuiteName", function(assert)
		-- Run lute test with --suite flag
		local result = process.run({ lutePath, "test", "-s", "SmokeSuite", "tests/cli/discovery" })

		-- Check that it runs only tests in SmokeSuite
		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("of 2", 1, true), nil)
		assert.neq(result.stdout:find("2 passed", 1, true), nil)
	end)

	suite:case("luteTestFiltersByCaseName", function(assert)
		-- Run lute test with --case flag
		local result = process.run({ lutePath, "test", "--case", "makePass", "tests/cli/discovery" })

		-- Check that it runs only tests named make_pass
		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("of 1", 1, true), nil)
		assert.neq(result.stdout:find("1 passed", 1, true), nil)
	end)

	suite:case("luteTestFiltersBySuiteAndCaseName", function(assert)
		-- Run lute test with both --suite and --case flags
		local result = process.run({ lutePath, "test", "-s", "SmokeSuite", "-c", "makeFail", "tests/cli/discovery" })

		-- Check that it runs only make_fail in SmokeSuite
		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("of 1", 1, true), nil)
		assert.neq(result.stdout:find("1 passed", 1, true), nil)
	end)
end)
