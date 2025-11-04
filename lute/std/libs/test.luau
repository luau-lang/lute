--!strict
local ps = require("@std/process")
local assert = require("@std/assert")
-- Test Types
type Test = (assert.Asserts) -> ()
type TestCase = { name: string, case: Test }

type TestSuite = {
	name: string,
	cases: { TestCase },
	_beforeeach: (() -> ())?,
	_beforeall: (() -> ())?,
	_aftereach: (() -> ())?,
	_afterall: (() -> ())?,
	case: (self: TestSuite, string, Test) -> (),
	beforeeach: (self: TestSuite, () -> ()) -> (),
	beforeall: (self: TestSuite, () -> ()) -> (),
	aftereach: (self: TestSuite, () -> ()) -> (),
	afterall: (self: TestSuite, () -> ()) -> (),
}

local TestSuite = {}
TestSuite.__index = TestSuite

function TestSuite.new(name: string): TestSuite
	local self = setmetatable({
		name = name,
		cases = {},
		_beforeeach = nil,
		_beforeall = nil,
		_aftereach = nil,
		_afterall = nil,
	}, TestSuite)
	return self :: TestSuite
end

function TestSuite:case(name: string, testCase: Test)
	table.insert(self.cases, { name = name, case = testCase })
end

function TestSuite:beforeeach(hook: () -> ())
	self._beforeeach = hook
end

function TestSuite:beforeall(hook: () -> ())
	self._beforeall = hook
end

function TestSuite:aftereach(hook: () -> ())
	self._aftereach = hook
end

function TestSuite:afterall(hook: () -> ())
	self._afterall = hook
end

-- Test Reporting
type FailedTest = {
	test: string, -- name of the test case that failed
	assertion: string?, -- name of the assertion that failed (e.g., "assert.eq")
	error: string?, -- the error message from the assertion
	filename: string, -- source file where the failure occurred
	linenumber: number, -- line number of the failure
}

type TestRunResult = {
	failures: { FailedTest },
	total: number,
	failed: number,
	passed: number,
}

local function printFailedTest(failed: FailedTest)
	print(`❌ {failed.test}`)
	print(`   {failed.filename}:{failed.linenumber}`)
	if failed.assertion ~= nil and failed.error ~= nil then
		print(`   	{failed.assertion}: {failed.error}`)
	end
	print()
end

local function simpleReporter(result: TestRunResult)
	print("\n" .. string.rep("=", 50))
	print("TEST RESULTS")
	print(string.rep("=", 50))

	if #result.failures > 0 then
		print(`\nFailed Tests ({#result.failures}):\n`)
		for _, failed in result.failures do
			printFailedTest(failed)
		end
	end

	print(string.rep("-", 50))
	print(`Total:  {result.total}`)
	print(`Passed: {result.passed} ✓`)
	print(`Failed: {result.failed} ✗`)
	print(string.rep("=", 50) .. "\n")
end

export type TestReporter = (TestRunResult) -> ()

-- Testing Environment
type TestEnvironment = {
	anonymous: { TestCase },
	suites: { TestSuite },
	reporter: TestReporter,
}

local env: TestEnvironment = { anonymous = {}, suites = {}, reporter = simpleReporter }

-- Test library export surface
local test = {}

function test.setreporter(reporter: TestReporter)
	test.reporter = reporter
end

-- register an anonymous test case
function test.case(name: string, case: Test)
	local testcase = { name = name, case = case }
	table.insert(env.anonymous, testcase)
end

-- register a test suite
function test.suite(name: string, registerFn: (TestSuite) -> ())
	local suite = TestSuite.new(name)
	registerFn(suite)
	table.insert(env.suites, suite)
end

-- get all registered tests without running them (internal)
function test._registered()
	return table.freeze({ anonymous = env.anonymous, suites = env.suites })
end

-- run all the tests
function test.run()
	local failures: { FailedTest } = {}
	local total = 0
	local failed = 0
	local passed = 0

	-- Error handler for beforeall hook
	local function beforeallErrorHandler(suite: TestSuite)
		return function(err)
			-- If beforeall fails, skip all tests in the suite
			total += #suite.cases
			failed += #suite.cases
			for _, tc in suite.cases do
				local failedtest: FailedTest = {
					test = `{suite.name}.{tc.name}`,
					assertion = "beforeall",
					error = `beforeall hook failed: {err}`,
					filename = "",
					linenumber = 0,
				}
				table.insert(failures, failedtest)
			end
			return tostring(err)
		end
	end

	-- Error handler for beforeeach hook
	local function beforeeachErrorHandler(testFullName: string)
		return function(err)
			failed += 1
			local failedtest: FailedTest = {
				test = testFullName,
				assertion = "beforeeach",
				error = `beforeeach hook failed: {err}`,
				filename = "",
				linenumber = 0,
			}
			table.insert(failures, failedtest)
			return tostring(err)
		end
	end

	-- Error handler for aftereach hook
	local function afterachErrorHandler(testFullName: string)
		return function(err)
			local failedtest: FailedTest = {
				test = testFullName,
				assertion = "aftereach",
				error = `aftereach hook failed: {err}`,
				filename = "",
				linenumber = 0,
			}
			table.insert(failures, failedtest)
			return tostring(err)
		end
	end

	-- Error handler for afterall hook
	local function afterallErrorHandler(suiteName: string)
		return function(err)
			failed += 1
			local failedtest: FailedTest = {
				test = suiteName,
				assertion = "afterall",
				error = `afterall hook failed: {err}`,
				filename = "",
				linenumber = 0,
			}
			table.insert(failures, failedtest)
			return tostring(err)
		end
	end

	-- Run anonymous tests
	for _, tc in env.anonymous do
		total += 1
		local function handlefailure(err)
			local fileName, lineNumber = debug.info(4, "sl")
			local assertName = debug.info(3, "n")

			if assertName == "xpcall" then
				fileName, lineNumber = debug.info(2, "sl")
			end

			local failedtest: FailedTest = {
				test = tc.name,
				assertion = if assertName == "xpcall" then nil else assertName,
				error = if assertName == "xpcall" then nil else err.msg,
				filename = fileName,
				linenumber = lineNumber,
			}
			table.insert(failures, failedtest)
			failed += 1
		end

		local success = xpcall(tc.case, handlefailure, assert)
		if success then
			passed += 1
		end
	end

	-- Run tests from suites
	for _, suite in env.suites do
		-- Run beforeall hook once per suite
		if suite._beforeall then
			local beforeallSuccess = xpcall(suite._beforeall, beforeallErrorHandler(suite))
			if not beforeallSuccess then
				-- If beforeall fails, skip all tests in the suite
				continue
			end
		end

		for _, tc in suite.cases do
			total += 1
			local testFullName = `{suite.name}.{tc.name}`
			local function handlefailure(err)
				local fileName, lineNumber = debug.info(4, "sl")
				local assertName = debug.info(3, "n")

				if assertName == "xpcall" then
					fileName, lineNumber = debug.info(2, "sl")
				end

				local failedtest: FailedTest = {
					test = testFullName,
					assertion = if assertName == "xpcall" then nil else assertName,
					error = if assertName == "xpcall" then nil else err.msg,
					filename = fileName,
					linenumber = lineNumber,
				}
				table.insert(failures, failedtest)
			end

			-- Run beforeeach hook if it exists
			if suite._beforeeach then
				local beforeSuccess = xpcall(suite._beforeeach, beforeeachErrorHandler(testFullName))
				if not beforeSuccess then
					continue
				end
			end

			local success = xpcall(tc.case, handlefailure, assert)
			-- Run aftereach hook if it exists (runs even if test failed)
			if suite._aftereach then
				local afterSuccess = xpcall(suite._aftereach, afterachErrorHandler(testFullName))
				if not afterSuccess then
					-- If test passed but aftereach failed, mark as failed
					success = false
				end
			end
			-- if the test and the teardown method passed, the test passes
			if success then
				passed += 1
			else
				failed += 1
			end
		end

		-- Run afterall hook once per suite (runs even if tests failed)
		if suite._afterall then
			xpcall(suite._afterall, afterallErrorHandler(suite.name))
		end
	end

	local result: TestRunResult = {
		failures = failures,
		total = total,
		failed = failed,
		passed = passed,
	}
	env.reporter(result)
	if failed ~= 0 then
		ps.exit(1)
	end
	ps.exit(0)
end

return table.freeze(test)
