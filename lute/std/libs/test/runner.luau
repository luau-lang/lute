--!strict
-- @std/test/runner
-- Standard test runner library for Luau
local ps = require("@std/process")

local asserts = require("./assert")
local failure = require("./failure")
local reporter = require("./reporter")
local types = require("./types")
local env = require("./env")

type Test = types.Test
type TestCase = types.TestCase
type TestSuite = types.TestSuite
type TestEnvironment = types.TestEnvironment
type TestReporter = types.TestReporter
type FailedTest = types.FailedTest
type TestRunResult = types.TestRunResult

local runner = {}

--- Runs all test cases and suites in `env`, executing lifecycle hooks around each case. Returns the aggregate results.
function runner.run(env: TestEnvironment): TestRunResult
	local failures: { FailedTest } = {}
	local total = 0
	local failed = 0
	local passed = 0

	-- Error handler for beforeAll hook
	local function beforeAllErrorHandler(suite: TestSuite)
		return function(err)
			-- If beforeAll fails, skip all tests in the suite
			total += #suite.cases
			failed += #suite.cases
			for _, tc in suite.cases do
				local failedtest: FailedTest = {
					test = `{suite.name}.{tc.name}`,
					failure = failure.lifecycle("beforeAll", err),
				}
				table.insert(failures, failedtest)
			end
			return err
		end
	end

	-- Error handler for beforeEach hook
	local function beforeEachErrorHandler(testFullName: string)
		return function(err)
			failed += 1
			local failedtest: FailedTest = {
				test = testFullName,
				failure = failure.lifecycle("beforeEach", err),
			}
			table.insert(failures, failedtest)
			return err
		end
	end

	-- Error handler for afterEach hook
	local function afterEachErrorHandler(testFullName: string)
		return function(err)
			local failedtest: FailedTest = {
				test = testFullName,
				failure = failure.lifecycle("afterEach", err),
			}
			table.insert(failures, failedtest)
			return err
		end
	end

	-- Error handler for afterAll hook
	local function afterAllErrorHandler(suiteName: string)
		return function(err)
			failed += 1
			local failedtest: FailedTest = {
				test = suiteName,
				failure = failure.lifecycle("afterAll", err),
			}
			table.insert(failures, failedtest)
			return err
		end
	end

	-- Run anonymous tests
	for _, tc in env.anonymous do
		total += 1
		local function handlefailure(err)
			local wasruntimefailure = not (typeof(err) == "table" and err.__tag and err.__tag == "assertion")
			local failedtest: FailedTest = {
				test = tc.name,
				failure = if wasruntimefailure then failure.runtimeerror(err) else err,
			}
			table.insert(failures, failedtest)
			failed += 1
		end

		local success = xpcall(tc.case, handlefailure, asserts)
		if success then
			passed += 1
		end
	end

	-- Run tests from suites
	for _, suite in env.suites do
		-- Run beforeAll hook once per suite
		if suite._beforeAll then
			local beforeAllSuccess = xpcall(suite._beforeAll, beforeAllErrorHandler(suite))
			if not beforeAllSuccess then
				-- If beforeAll fails, skip all tests in the suite
				continue
			end
		end

		for _, tc in suite.cases do
			total += 1
			local testFullName = `{suite.name}.{tc.name}`
			local function handlefailure(err)
				local wasruntimefailure = not (typeof(err) == "table" and err.__tag and err.__tag == "assertion")
				local failedtest: FailedTest = {
					test = testFullName,
					failure = if wasruntimefailure then failure.runtimeerror(err) else err,
				}
				table.insert(failures, failedtest)
			end

			-- Run beforeEach hook if it exists
			if suite._beforeEach then
				local beforeSuccess = xpcall(suite._beforeEach, beforeEachErrorHandler(testFullName))
				if not beforeSuccess then
					continue
				end
			end

			local success = xpcall(tc.case, handlefailure, asserts)
			-- Run afterEach hook if it exists (runs even if test failed)
			if suite._afterEach then
				local afterSuccess = xpcall(suite._afterEach, afterEachErrorHandler(testFullName))
				if not afterSuccess then
					-- If test passed but afterEach failed, mark as failed
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

		-- Run afterAll hook once per suite (runs even if tests failed)
		if suite._afterAll then
			xpcall(suite._afterAll, afterAllErrorHandler(suite.name))
		end
	end

	return {
		failures = failures,
		total = total,
		failed = failed,
		passed = passed,
	}
end

--- Runs all globally registered tests, prints the results with the simple reporter, then exits the process with code 0 on success or 1 on failure.
function runner.runRegisteredTests()
	local result = runner.run(env)
	reporter.simple(result)
	if result.failed ~= 0 then
		ps.exit(1)
	end
	ps.exit(0)
end

return table.freeze(runner)
