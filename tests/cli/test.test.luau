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

	suite:case("lute test discovers test files in custom directory", function(assert)
		-- Run lute test with custom directory path
		local result = process.run({ lutePath, "test", "--list", "tests/cli/discovery" })

		-- Check that it discovers test files (.test.luau and .spec.luau)
		assert.eq(result.exitcode, 0)
		assert.eq(expected, result.stdout)
	end)
end)

test.run()
