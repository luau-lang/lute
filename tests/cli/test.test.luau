local assertions = require("@std/test/assert")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

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

local function assertErrorsWithMsg(
	testName: string,
	testContents: string,
	expectedErrMsg: string,
	assert: assertions.asserts
)
	local testFilePath = path.join(tmpDir, `{testName}.test.luau`)
	fs.writestringtofile(testFilePath, testContents)

	-- Run lute on the created test file
	local result = process.run({ lutePath, tostring(testFilePath) })

	-- Check that the output specifies the inequal values
	assert.eq(result.exitcode, 1)
	assert.strcontains(result.stdout, expectedErrMsg)
end

test.suite("lute test", function(suite)
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

	suite:case("lute doesn't report xpcall as error when accessing field of nil in suite", function(assert)
		-- Setup
		local testFilePath = path.join(tmpDir, "nil_field_access_test.test.luau")
		fs.writestringtofile(
			testFilePath,
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

		-- Run lute on the created test file
		local result = process.run({ lutePath, path.format(testFilePath) })
		-- Check that the output doesn't include xpcall
		assert.eq(result.exitcode, 1)
		assert.eq(result.stdout:find("xpcall", 1, true), nil)
		-- Check that the error points to filepath + correct line number
		assert.strcontains(result.stdout, `Failed with: Runtime error in nil_field_suite.access_field_of_nil in:`)
		assert.strcontains(
			result.stdout,
			`{if system.win32 then path.format(testFilePath):gsub("\\", "/") else path.format(testFilePath)}:6`
		)

		fs.remove(testFilePath)
	end)

	suite:case("lute doesn't report xpcall as error when accessing field of nil in case", function(assert)
		-- Setup
		local testFilePath = path.join(tmpDir, "nil_field_access_test.test.luau")
		fs.writestringtofile(
			testFilePath,
			[[
local test = require("@std/test")

test.case("access_field_of_nil", function(assert)
	local t = nil
	local value = t.field -- This will cause an error
end)

test.run()
			]]
		)

		-- Run lute on the created test file
		local result = process.run({ lutePath, path.format(testFilePath) })

		-- Check that the output doesn't include xpcall
		assert.eq(result.exitcode, 1)
		assert.eq(result.stdout:find("xpcall", 1, true), nil)
		-- Check that the error points to filepath + correct line number
		assert.strcontains(result.stdout, `Failed with: Runtime error in access_field_of_nil in:`)
		assert.strcontains(
			result.stdout,
			`{if system.win32 then path.format(testFilePath):gsub("\\", "/") else path.format(testFilePath)}:5`
		)

		fs.remove(testFilePath)
	end)

	suite:case("assert.eq_error_message_in_case", function(assert)
		assertErrorsWithMsg(
			"assert_eq_fails",
			[[
local test = require("@std/test")

test.case("eq_error", function(assert)
	assert.eq(1, 2)
end)

test.run()
			]],
			"eq: 1 ~= 2",
			assert
		)
	end)

	suite:case("assert.eq_error_message_in_suite", function(assert)
		assertErrorsWithMsg(
			"assert_eq_fails",
			[[
local test = require("@std/test")

test.suite("eq_failure_suite", function(suite)
	suite:case("eq_error", function(assert)
		assert.eq(1, 2)
	end)
end)

test.run()
			]],
			"eq: 1 ~= 2",
			assert
		)
	end)

	suite:case("assert.neq_error_message_in_case", function(assert)
		assertErrorsWithMsg(
			"assert_neq_fails",
			[[
local test = require("@std/test")

test.case("neq_error", function(assert)
	assert.neq(1, 1)
end)

test.run()
			]],
			"neq: 1 == 1",
			assert
		)
	end)

	suite:case("assert.neq_error_message_in_suite", function(assert)
		assertErrorsWithMsg(
			"assert_neq_fails",
			[[
local test = require("@std/test")

test.suite("neq_failure_suite", function(suite)
	suite:case("neq_error", function(assert)
		assert.neq(1, 1)
	end)
end)

test.run()
			]],
			"neq: 1 == 1",
			assert
		)
	end)

	suite:case("assert.tableeq_error_message_in_case", function(assert)
		assertErrorsWithMsg(
			"assert_tableeq_fails",
			[[
local test = require("@std/test")

test.case("tableeq_error", function(assert)
	assert.tableeq({ a = 1 }, { a = 2 })
end)

test.run()
			]],
			"tableeq: lhs[a] = 1 but rhs[a] = 2",
			assert
		)
	end)

	suite:case("assert.tableeq_error_message_in_suite", function(assert)
		assertErrorsWithMsg(
			"assert_tableeq_fails",
			[[
local test = require("@std/test")

test.suite("tableeq_failure_suite", function(suite)
	suite:case("tableeq_error", function(assert)
		assert.tableeq({ a = 1 }, { a = 2 })
	end)
end)

test.run()
			]],
			"tableeq: lhs[a] = 1 but rhs[a] = 2",
			assert
		)
	end)

	suite:case("assert.buffereq_unequal_length", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")

test.case("buffereq_error", function(assert)
	local buf1 = buffer.create(1)
	local buf2 = buffer.create(2)
	assert.buffereq(buf1, buf2)
end)

test.run()
			]],
			"buffers are of unequal length",
			assert
		)
	end)

	suite:case("assert.buffereq_error_message_in_suite", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")

test.suite("buffereq_failure_suite", function(suite)
	suite:case("buffereq_error", function(assert)
		local buf1 = buffer.create(2)
		local buf2 = buffer.create(2)
		buffer.writeu8(buf1, 0, 84)
		buffer.writeu8(buf2, 0, 85)
		assert.buffereq(buf1, buf2)
	end)
end)

test.run()
			]],
			"buffereq: lhs[0] = 54, but rhs[0] = 55",
			assert
		)
	end)

	suite:case("assert.erroreq_no_error", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")

test.case("erroreq_error", function(assert)
	assert.erroreq(function() return end, "expected message")
end)

test.run()
			]],
			"Function did not error as expected.",
			assert
		)
	end)

	suite:case("assert.erroreq_error_message", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")

test.suite("erroreq_failure_suite", function(suite)
	suite:case("erroreq_error", function(assert)
		assert.erroreq(function() error("wrong message") end, "expected message")
	end)
end)

test.run()
			]],
			'Expected suffix of error message "expected message", but got ', -- the full message contains tmpdir path to test file
			assert
		)
	end)

	suite:case("assert.strcontains_instances_negative", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")

test.case("strcontains_error", function(assert)
	assert.strcontains("hello world", "goodbye", nil, -1)
end)

test.run()
			]],
			"instances must be greater than 0",
			assert
		)
	end)

	suite:case("assert.strcontains_single_instance_fails", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")

test.suite("strcontains_failure_suite", function(suite)
	suite:case("strcontains_error", function(assert)
		assert.strcontains("hello world", "goodbye")
	end)
end)

test.run()
			]],
			'Expected "hello world" to contain "goodbye".',
			assert
		)
	end)

	suite:case("assert.strcontains_multiple_instance_fails", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")

test.suite("strcontains_failure_suite", function(suite)
	suite:case("strcontains_error", function(assert)
		assert.strcontains("muahahahaha", "ha", nil, 5)
	end)
end)

test.run()
			]],
			'Expected "muahahahaha" to contain "ha" 5 times.',
			assert
		)
	end)
end)

test.run()
