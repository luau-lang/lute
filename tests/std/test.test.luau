local testtypes = require("@std/test/types")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execpath())
local tmpDir = system.tmpdir()

local function assertErrorsWithMsg(
	testName: string,
	testContents: string,
	expectedErrMsg: string,
	assert: testtypes.Asserts
)
	local testFilePath = path.join(tmpDir, `{testName}.test.luau`)
	fs.writestringtofile(testFilePath, testContents)

	-- Run lute on the created test file
	local result = process.run({ lutePath, tostring(testFilePath) })

	-- Check that the output specifies the inequal values
	assert.eq(result.exitcode, 1)
	assert.strcontains(result.stdout, expectedErrMsg)
end

test.suite("LuteStdTestFramework", function(suite)
	suite:case("luteDoesntReportXpcallAsErrorWhenAccessingFieldOfNilInSuite", function(assert)
		-- Setup
		local testFilePath = path.join(tmpDir, "nil_field_access_test.test.luau")
		fs.writestringtofile(
			testFilePath,
			[[
local test = require("@std/test")

test.suite("nil_field_suite", function(suite)
	suite:case("accessFieldOfNil", function(assert)
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
		assert.strcontains(result.stdout, `Runtime error`)
		assert.strcontains(
			result.stdout,
			`{if system.win32 then path.format(testFilePath):gsub("\\", "/") else path.format(testFilePath)}:6`
		)
		assert.strcontains(result.stdout, `nil_field_access_test.test.luau:6: attempt to index nil with 'field'`)
		assert.strcontains(result.stdout, `nil_field_access_test.test.luau:10`)

		fs.remove(testFilePath)
	end)

	suite:case("luteDoesntReportXpcallAsErrorWhenAccessingFieldOfNilInCase", function(assert)
		-- Setup
		local testFilePath = path.join(tmpDir, "nil_field_access_test.test.luau")
		fs.writestringtofile(
			testFilePath,
			[[
local test = require("@std/test")

test.case("accessFieldOfNil", function(assert)
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
		assert.strcontains(result.stdout, `Runtime error`)
		assert.strcontains(
			result.stdout,
			`{if system.win32 then path.format(testFilePath):gsub("\\", "/") else path.format(testFilePath)}:5`
		)
		assert.strcontains(result.stdout, `nil_field_access_test.test.luau:5: attempt to index nil with 'field'`)
		assert.strcontains(result.stdout, `nil_field_access_test.test.luau:8`)

		fs.remove(testFilePath)
	end)

	suite:case("assert.eqErrorMessageInCase", function(assert)
		assertErrorsWithMsg(
			"assert_eq_fails",
			[[
local test = require("@std/test")

test.case("eqError", function(assert)
	assert.eq(1, 2)
end)

test.run()
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

test.suite("eq_failure_suite", function(suite)
	suite:case("eqError", function(assert)
		assert.eq(1, 2)
	end)
end)

test.run()
			]],
			"eq: 1 ~= 2",
			assert
		)
	end)

	suite:case("assert.eqTableEqErrorMessageInCase", function(assert)
		assertErrorsWithMsg(
			"assert_eq_fails",
			[[
local test = require("@std/test")

test.case("eqOnTableError", function(assert)
	assert.eq({ a = 1 }, { a = 2 })
end)

test.run()
			]],
			"tableeq: lhs[a] = 1 but rhs[a] = 2",
			assert
		)
	end)

	suite:case("assert.eqTableEqErrorMessageInSuite", function(assert)
		assertErrorsWithMsg(
			"assert_eq_fails",
			[[
local test = require("@std/test")

test.suite("eq_failure_suite", function(suite)
	suite:case("eqOnTableError", function(assert)
		assert.eq({ a = 1 }, { a = 2 })
	end)
end)

test.run()
			]],
			"tableeq: lhs[a] = 1 but rhs[a] = 2",
			assert
		)
	end)

	suite:case("assert.eqBufferEqUnequalLength", function(assert)
		assertErrorsWithMsg(
			"assert_eq_fails",
			[[
local test = require("@std/test")

test.case("eqOnBufferError", function(assert)
	local buf1 = buffer.create(1)
	local buf2 = buffer.create(2)
	assert.eq(buf1, buf2)
end)

test.run()
			]],
			"buffers are of unequal length",
			assert
		)
	end)

	suite:case("assert.eqBufferEqErrorMessageInSuite", function(assert)
		assertErrorsWithMsg(
			"assert_eq_fails",
			[[
local test = require("@std/test")

test.suite("buffereq_failure_suite", function(suite)
	suite:case("eqOnBufferError", function(assert)
		local buf1 = buffer.create(2)
		local buf2 = buffer.create(2)
		buffer.writeu8(buf1, 0, 84)
		buffer.writeu8(buf2, 0, 85)
		assert.eq(buf1, buf2)
	end)
end)

test.run()
			]],
			"buffereq: lhs[0] = 54, but rhs[0] = 55",
			assert
		)
	end)

	suite:case("assert.neqErrorMessageInCase", function(assert)
		assertErrorsWithMsg(
			"assert_neq_fails",
			[[
local test = require("@std/test")

test.case("neqError", function(assert)
	assert.neq(1, 1)
end)

test.run()
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

test.suite("neq_failure_suite", function(suite)
	suite:case("neqError", function(assert)
		assert.neq(1, 1)
	end)
end)

test.run()
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

test.case("tableeqError", function(assert)
	assert.tableeq({ a = 1 }, { a = 2 })
end)

test.run()
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

test.suite("tableeq_failure_suite", function(suite)
	suite:case("tableeqError", function(assert)
		assert.tableeq({ a = 1 }, { a = 2 })
	end)
end)

test.run()
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

test.case("buffereqError", function(assert)
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

	suite:case("assert.buffereqErrorMessageInSuite", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")

test.suite("buffereq_failure_suite", function(suite)
	suite:case("buffereqError", function(assert)
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

	suite:case("assert.erroreqNoError", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")

test.case("erroreqError", function(assert)
	assert.erroreq(function() return end, "expected message")
end)

test.run()
			]],
			"Function did not error as expected.",
			assert
		)
	end)

	suite:case("assert.erroreqErrorMessage", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")

test.suite("erroreq_failure_suite", function(suite)
	suite:case("erroreqError", function(assert)
		assert.erroreq(function() error("wrong message") end, "expected message")
	end)
end)

test.run()
			]],
			'Expected suffix of error message "expected message", but got ', -- the full message contains tmpdir path to test file
			assert
		)
	end)

	suite:case("assert.strcontainsInstancesNegative", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")

test.case("strcontainsError", function(assert)
	assert.strcontains("hello world", "goodbye", -1)
end)

test.run()
			]],
			"instances must be greater than 0",
			assert
		)
	end)

	suite:case("assert.strcontainsSingleInstanceFails", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")

test.suite("strcontains_failure_suite", function(suite)
	suite:case("strcontainsError", function(assert)
		assert.strcontains("hello world", "goodbye")
	end)
end)

test.run()
			]],
			'Expected "hello world" to contain "goodbye".',
			assert
		)
	end)

	suite:case("assert.strcontainsMultipleInstanceFails", function(assert)
		assertErrorsWithMsg(
			"assert_buffereq_fails",
			[[
local test = require("@std/test")

test.suite("strcontains_failure_suite", function(suite)
	suite:case("strcontainsError", function(assert)
		assert.strcontains("muahahahaha", "ha", 5)
	end)
end)

test.run()
			]],
			'Expected "muahahahaha" to contain "ha" 5 times.',
			assert
		)
	end)
end)
