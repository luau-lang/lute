local path = require("@std/path")
local process = require("@std/process")
local test = require("@std/test")

local lutePath = path.format(process.execpath())

test.suite("lute test", function(suite)
	suite:case("lute test help message", function(assert)
		-- Run lute test with -h flag
		local result = process.run({ lutePath, "test", "-h" })

		-- Check that it exits successfully and prints help
		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("Usage:", 1, true), nil)
	end)

	suite:case("lute test runs successfully", function(assert)
		-- Run lute test without arguments
		local result = process.run({ lutePath, "test" })

		-- Check that it succeeds
		assert.eq(result.exitcode, 0)
	end)
end)

test.run()
