--!strict
local ps = require("@lute/process")
type Test = () -> ()

type Test = () -> ()
local assert = require("./assert")
-- Test Types
type Test = (assert.Asserts) -> ()
type TestCase = { name: string, case: Test }

type TestSuite = { name: string, cases: { TestCase } }
type Suite = {
	case: (string, Test) -> (),
}

local function makesuite(name: string): (TestSuite, Suite)
	local data: TestSuite = { name = name, cases = {} }
	return data,
		{
			case = function(name: string, case: Test)
				table.insert(data.cases, { name = name, case = case })
			end,
		}
end

-- Test Reporting
type FailedTest = {
	test: string, -- name of the test case that failed
	assertion: string, -- name of the assertion that failed (e.g., "assert.eq")
	error: string, -- the error message from the assertion
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
	print(`   	{failed.assertion}: {failed.error}`)
	print()
end

function simpleReporter(result: TestRunResult)
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
function test.suite(name: string, registerSuite: (Suite) -> ())
	local suiteinternal, suiteexternal = makesuite(name)
	registerSuite(suiteexternal)
	table.insert(env.suites, suiteinternal)
end

-- run all the tests
function test.run()
	local failures: { FailedTest } = {}
	local total = 0
	local failed = 0
	local passed = 0

	-- Run anonymous tests
	for _, tc in env.anonymous do
		total += 1
		local function handlefailure(err)
			local fileName, lineNumber = debug.info(4, "sl")
			local assertName = debug.info(3, "n")

			local failedtest: FailedTest = {
				test = tc.name,
				assertion = assertName,
				error = err.msg,
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
		for _, tc in suite.cases do
			total += 1
			local function handlefailure(err)
				local fileName, lineNumber = debug.info(4, "sl")
				local assertName = debug.info(3, "n")

				local failedtest: FailedTest = {
					test = `{suite.name}.{tc.name}`,
					assertion = assertName,
					error = err.msg,
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
