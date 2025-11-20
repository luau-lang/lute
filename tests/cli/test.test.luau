local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")
local fs = require("@std/fs")
local lutePath = path.format(process.execpath())
local tmpDir = system.tmpdir()

local expected = [[Anonymous:
	Passing
ExampleSuite:
	should pass
SmokeSuite:
	make_fail
	make_pass
]]

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
		local result = process.run({ lutePath, "test", "--list", "tests/cli/discovery" })

		-- Check that it discovers test files (.test.luau and .spec.luau)
		assert.eq(result.exitcode, 0)
		assert.eq(expected, result.stdout)
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
		-- Check that the error points to filepath + correct line number
		assert.neq(
			result.stdout:find(`Failed with: Runtime error in nil_field_suite.access_field_of_nil in:`, 1, true),
			nil
		)
		print("EXPECTED PATH: ", path.format(testFilePath))
		print("TEST OUTPUT: ", result.stdout)
		assert.neq(result.stdout:find(`{path.format(testFilePath)}:6`, 1, true), nil)

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
		-- Check that the error points to filepath + correct line number
		assert.neq(result.stdout:find(`Failed with: Runtime error in access_field_of_nil in:`, 1, true), nil)
		print("EXPECTED PATH: ", path.format(testFilePath))
		print("TEST OUTPUT: ", result.stdout)
		assert.neq(result.stdout:find(`{path.format(testFilePath)}:5`, 1, true), nil)

		fs.remove(testFilePath)
	end)

	suite:case("assert.eq_error_message_in_case", function(assert)
		local testFilePath = path.join(tmpDir, "assert_eq_fails.test.luau")
		local handle = fs.open(testFilePath, "w+")
		fs.write(
			handle,
			[[
local test = require("@std/test")

test.case("eq_error", function(assert)
	assert.eq(1, 2)
end)

test.run()
			]]
		)
		fs.close(handle)

		-- Run lute on the created test file
		local result = process.run({ lutePath, tostring(testFilePath) })

		-- Check that the output specifies the inequal values
		assert.eq(result.exitcode, 1)
		assert.neq(result.stdout:find("eq: 1 ~= 2", 1, true), nil)
	end)

	suite:case("assert.eq_error_message_in_suite", function(assert)
		local testFilePath = path.join(tmpDir, "assert_eq_fails.test.luau")
		local handle = fs.open(testFilePath, "w+")
		fs.write(
			handle,
			[[
local test = require("@std/test")

test.suite("eq_failure_suite", function(suite)
	suite:case("eq_error", function(assert)
		assert.eq(1, 2)
	end)
end)

test.run()
			]]
		)
		fs.close(handle)

		-- Run lute on the created test file
		local result = process.run({ lutePath, tostring(testFilePath) })

		-- Check that the output specifies the inequal values
		assert.eq(result.exitcode, 1)
		assert.neq(result.stdout:find("eq: 1 ~= 2", 1, true), nil)
	end)

	suite:case("assert.neq_error_message_in_case", function(assert)
		local testFilePath = path.join(tmpDir, "assert_neq_fails.test.luau")
		local handle = fs.open(testFilePath, "w+")
		fs.write(
			handle,
			[[
local test = require("@std/test")

test.case("neq_error", function(assert)
	assert.neq(1, 1)
end)

test.run()
			]]
		)
		fs.close(handle)

		-- Run lute on the created test file
		local result = process.run({ lutePath, tostring(testFilePath) })

		-- Check that the output specifies the inequal values
		assert.eq(result.exitcode, 1)
		assert.neq(result.stdout:find("neq: 1 == 1", 1, true), nil)
	end)

	suite:case("assert.neq_error_message_in_suite", function(assert)
		local testFilePath = path.join(tmpDir, "assert_neq_fails.test.luau")
		local handle = fs.open(testFilePath, "w+")
		fs.write(
			handle,
			[[
local test = require("@std/test")

test.suite("neq_failure_suite", function(suite)
	suite:case("neq_error", function(assert)
		assert.neq(1, 1)
	end)
end)

test.run()
			]]
		)
		fs.close(handle)

		-- Run lute on the created test file
		local result = process.run({ lutePath, tostring(testFilePath) })

		-- Check that the output specifies the inequal values
		assert.eq(result.exitcode, 1)
		assert.neq(result.stdout:find("neq: 1 == 1", 1, true), nil)
	end)
end)

test.run()
