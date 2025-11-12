--!strict
-- @std/test/runner
-- Standard test runner library for Luau

local types = require("./types")
local asserts = require("./assert")

type Test = types.Test
type TestCase = types.TestCase
type TestSuite = types.TestSuite
type TestEnvironment = types.TestEnvironment
type TestReporter = types.TestReporter
type FailedTest = types.FailedTest
type TestRunResult = types.TestRunResult

local runner = {}

function runner.run(env: TestEnvironment): TestRunResult
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
			local assertName: string = debug.info(3, "n")

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

		local success = xpcall(tc.case, handlefailure, asserts)
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

			local success = xpcall(tc.case, handlefailure, asserts)
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

	return {
		failures = failures,
		total = total,
		failed = failed,
		passed = passed,
	}
end

return table.freeze(runner)
