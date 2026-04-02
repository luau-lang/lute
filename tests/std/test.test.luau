local testtypes = require("@std/test/types")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execPath())
local tmpDir = system.tmpdir()

local function assertErrorsWithMsg(
	testName: string,
	testContents: string,
	expectedErrMsg: string,
	assert: testtypes.Asserts
)
	local testFilePath = path.join(tmpDir, `{testName}.test.luau`)
	fs.writeStringToFile(testFilePath, testContents)

	-- Run lute on the created test file
	local result = process.run({ lutePath, tostring(testFilePath) })

	-- Check that the output specifies the inequal values
	assert.eq(result.exitcode, 1)
	assert.strContains(result.stdout, expectedErrMsg)
end

test.suite("LuteStdTestFramework", function(suite)
	suite:case("luteDoesntReportXpcallAsErrorWhenAccessingFieldOfNilInSuite", function(assert)
		-- Setup
		local testFilePath = path.join(tmpDir, "nil_field_access_test.test.luau")
		fs.writeStringToFile(
			testFilePath,
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")
test.suite("nil_field_suite", function(suite)
	suite:case("accessFieldOfNil", function(assert)
		local t = nil
		local value = t.field -- This will cause an error
	end)
end)

runner.runRegisteredTests()
			]]
		)

		-- Run lute on the created test file
		local result = process.run({ lutePath, path.format(testFilePath) })
		-- Check that the output doesn't include xpcall
		assert.eq(result.exitcode, 1)
		assert.eq(result.stdout:find("xpcall", 1, true), nil)
		-- Check that the error points to filepath + correct line number
		assert.strContains(result.stdout, `Runtime error`)
		assert.strContains(
			result.stdout,
			`{if system.win32 then path.format(testFilePath):gsub("\\", "/") else path.format(testFilePath)}:6`
		)
		assert.strContains(result.stdout, `nil_field_access_test.test.luau:6: attempt to index nil with 'field'`)
		assert.strContains(result.stdout, `nil_field_access_test.test.luau:10`)

		fs.remove(testFilePath)
	end)

	suite:case("luteDoesntReportXpcallAsErrorWhenAccessingFieldOfNilInCase", function(assert)
		-- Setup
		local testFilePath = path.join(tmpDir, "nil_field_access_test.test.luau")
		fs.writeStringToFile(
			testFilePath,
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")

test.case("accessFieldOfNil", function(assert)
	local t = nil
	local value = t.field -- This will cause an error
end)

runner.runRegisteredTests()
			]]
		)

		-- Run lute on the created test file
		local result = process.run({ lutePath, path.format(testFilePath) })

		-- Check that the output doesn't include xpcall
		assert.eq(result.exitcode, 1)
		assert.eq(result.stdout:find("xpcall", 1, true), nil)
		-- Check that the error points to filepath + correct line number
		assert.strContains(result.stdout, `Runtime error`)
		assert.strContains(
			result.stdout,
			`{if system.win32 then path.format(testFilePath):gsub("\\", "/") else path.format(testFilePath)}:6`
		)
		assert.strContains(result.stdout, `nil_field_access_test.test.luau:6: attempt to index nil with 'field'`)
		assert.strContains(result.stdout, `nil_field_access_test.test.luau:9`)

		fs.remove(testFilePath)
	end)

	suite:case("assert.eqErrorMessageInCase", function(assert)
		assertErrorsWithMsg(
			"assert_eq_fails",
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")

test.case("eqError", function(assert)
	assert.eq(1, 2)
end)

runner.runRegisteredTests()
			]],
			"eq: 1 ~= 2",
			assert
		)
	end)

	suite:case("assert.eqErrorMessageInSuite", function(assert)
		assertErrorsWithMsg(
			"assert_eq_fails",
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("eq_failure_suite", function(suite)
	suite:case("eqError", function(assert)
		assert.eq(1, 2)
	end)
end)

runner.runRegisteredTests()
			]],
			"eq: 1 ~= 2",
			assert
		)
	end)

	suite:case("assert.neqErrorMessageInCase", function(assert)
		assertErrorsWithMsg(
			"assert_neq_fails",
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")

test.case("neqError", function(assert)
	assert.neq(1, 1)
end)

runner.runRegisteredTests()
			]],
			"neq: 1 == 1",
			assert
		)
	end)

	suite:case("assert.neqErrorMessageInSuite", function(assert)
		assertErrorsWithMsg(
			"assert_neq_fails",
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("neq_failure_suite", function(suite)
	suite:case("neqError", function(assert)
		assert.neq(1, 1)
	end)
end)

runner.runRegisteredTests()
			]],
			"neq: 1 == 1",
			assert
		)
	end)

	suite:case("assert.tableeqErrorMessageInCase", function(assert)
		assertErrorsWithMsg(
			"assert_tableeq_fails",
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")

test.case("tableeqError", function(assert)
	assert.eq({ a = 1 }, { a = 2 })
end)

runner.runRegisteredTests()
			]],
			"tableeq: lhs[a] = 1 but rhs[a] = 2",
			assert
		)
	end)

	suite:case("assert.tableeqErrorMessageInSuite", function(assert)
		assertErrorsWithMsg(
			"assert_tableeq_fails",
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("tableeq_failure_suite", function(suite)
	suite:case("tableeqError", function(assert)
		assert.eq({ a = 1 }, { a = 2 })
	end)
end)

runner.runRegisteredTests()
			]],
			"tableeq: lhs[a] = 1 but rhs[a] = 2",
			assert
		)
	end)

	suite:case("assert.buffereqUnequalLength", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")

test.case("buffereqError", function(assert)
	local buf1 = buffer.create(1)
	local buf2 = buffer.create(2)
	assert.eq(buf1, buf2)
end)

runner.runRegisteredTests()
			]],
			"buffers are of unequal length",
			assert
		)
	end)

	suite:case("assert.buffereqErrorMessageInSuite", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("buffereq_failure_suite", function(suite)
	suite:case("buffereqError", function(assert)
		local buf1 = buffer.create(2)
		local buf2 = buffer.create(2)
		buffer.writeu8(buf1, 0, 84)
		buffer.writeu8(buf2, 0, 85)
		assert.eq(buf1, buf2)
	end)
end)

runner.runRegisteredTests()
			]],
			"buffereq: lhs[0] = 54, but rhs[0] = 55",
			assert
		)
	end)

	suite:case("assert.throwsWithNoError", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")

test.case("throwsWithError", function(assert)
	assert.throwsWith("expected message", function() return end)
end)

runner.runRegisteredTests()
			]],
			"Expected function to throw/raise error.",
			assert
		)
	end)

	suite:case("assert.throwsWithErrorMessage", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("throwsWith_failure_suite", function(suite)
	suite:case("throwsWithError", function(assert)
		assert.throwsWith("expected message", function() error("wrong message") end)
	end)
end)

runner.runRegisteredTests()
			]],
			'Expected suffix of error message "expected message", but got ', -- the full message contains tmpdir path to test file
			assert
		)
	end)

	suite:case("assert.strContainsInstancesNegative", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")

test.case("strcontainsError", function(assert)
	assert.strContains("hello world", "goodbye", -1)
end)

runner.runRegisteredTests()
			]],
			"instances must be greater than 0",
			assert
		)
	end)

	suite:case("assert.strContainsSingleInstanceFails", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("strcontains_failure_suite", function(suite)
	suite:case("strcontainsError", function(assert)
		assert.strContains("hello world", "goodbye")
	end)
end)

runner.runRegisteredTests()
			]],
			'Expected "hello world" to contain "goodbye".',
			assert
		)
	end)

	suite:case("assert.strContainsMultipleInstanceFails", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")
local runner = require("@std/test/runner")

test.suite("strcontains_failure_suite", function(suite)
	suite:case("strcontainsError", function(assert)
		assert.strContains("muahahahaha", "ha", 5)
	end)
end)

runner.runRegisteredTests()
			]],
			'Expected "muahahahaha" to contain "ha" 5 times.',
			assert
		)
	end)
end)
