--!strict

type Test = () -> ()
type TestCase = { name: string, case: Test }
type TestCases = { TestCase }
type TestSuite = { name: string, cases: TestCases }

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

type TestReporter = (TestRunResult) -> ()

local function printFailedTest(failed: FailedTest)
	print(`❌ {failed.test}`)
	print(`   {failed.filename}:{failed.linenumber}`)
	print(`   	{failed.assertion}: {failed.error}`)
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

type TestEnvironment = {
	anonymous: TestCases,
	suites: { TestSuite },
	reporter: TestReporter,
	active_suite: TestSuite?,
}

local env: TestEnvironment = { anonymous = {}, suites = {}, reporter = simpleReporter }

local test = {}
test.assert = {}
local assert = test.assert
-- todo: we should add some more assertions for diffing tables!
function assert.eq<T>(lhs: T, rhs: T)
	if lhs ~= rhs then
		error({ msg = `{lhs} ~= {rhs}` })
	end
end

function assert.neq<T>(lhs: T, rhs: T)
	if lhs == rhs then
		error({ msg = `{lhs} == {rhs}` })
	end
end

-- register a test case
function test.case(name: string, case: () -> ())
	local testcase = { name = name, case = case }
	if env.active_suite then
		local _, cases = env.active_suite.name, env.active_suite.cases
		table.insert(cases, testcase)
	else
		table.insert(env.anonymous, testcase)
	end
end

-- register a test suite
-- takes name and a function to register
function test.suite(name: string, registerSuite: () -> ())
	local testsuite: TestSuite = { name = name, cases = {} }
	table.insert(env.suites, testsuite)
	env.active_suite = testsuite
	registerSuite()
	env.active_suite = nil
end

function test.setreporter(reporter: TestReporter)
	test.reporter = reporter
end

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

		local success = xpcall(tc.case, handlefailure)
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

			local success = xpcall(tc.case, handlefailure)
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
end

return table.freeze(test)
