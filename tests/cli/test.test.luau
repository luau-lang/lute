local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execpath())
local tmpDir = system.tmpdir()

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

	suite:case("lute test discovers test files in custom directory", function(assert)
		-- Run lute test with custom directory path
		local result = process.run({ lutePath, "test", "tests/cli/discovery" })

		-- Check that it discovers test files (.test.luau and .spec.luau)
		assert.eq(result.exitcode, 0)
		assert.neq(result.stdout:find("Found 2 test files", 1, true), nil)
	end)

	suite:case("lute doesn't report xpcall as error when accessing field of nil in suite", function(assert)
		-- Setup
		local testFilePath = path.join(tmpDir, "nil_field_access_test.test.luau")
		local handle = fs.open(testFilePath, "w+")
		fs.write(
			handle,
			[[
local test = require("@std/test")

test.suite("nil_field_suite", function(suite)
	suite:case("access_field_of_nil", function(assert)
		local t = nil
		local value = t.field -- This will cause an error
	end)
end)

test.run()
			]]
		)
		fs.close(handle)

		-- Run lute on the created test file
		local result = process.run({ lutePath, tostring(testFilePath) })

		-- Check that the output doesn't include xpcall
		assert.eq(result.exitcode, 1)
		assert.eq(result.stdout:find("xpcall", 1, true), nil)
		assert.neq(result.stdout:find(tostring(testFilePath), 1, true), nil)

		fs.remove(testFilePath)
	end)

	suite:case("lute doesn't report xpcall as error when accessing field of nil in case", function(assert)
		-- Setup
		local testFilePath = path.join(tmpDir, "nil_field_access_test.test.luau")
		local handle = fs.open(testFilePath, "w+")
		fs.write(
			handle,
			[[
local test = require("@std/test")

test.case("access_field_of_nil", function(assert)
	local t = nil
	local value = t.field -- This will cause an error
end)

test.run()
			]]
		)
		fs.close(handle)

		-- Run lute on the created test file
		local result = process.run({ lutePath, tostring(testFilePath) })

		-- Check that the output doesn't include xpcall
		assert.eq(result.exitcode, 1)
		assert.eq(result.stdout:find("xpcall", 1, true), nil)
		assert.neq(result.stdout:find(tostring(testFilePath), 1, true), nil)

		fs.remove(testFilePath)
	end)
end)

test.run()
