--!strict
-- @std/test/types
-- Standard test types library for Luau

--- The name of a lifecycle hook that can run around test cases:
--- - `"beforeEach"`: Runs before each test case in the suite.
--- - `"beforeAll"`: Runs once before all test cases in the suite.
--- - `"afterEach"`: Runs after each test case in the suite.
--- - `"afterAll"`: Runs once after all test cases in the suite.
export type Hook = "beforeEach" | "beforeAll" | "afterEach" | "afterAll"
--- Describes why a test failed:
--- - `"assertion"`: An assertion (e.g. `t.eq`) failed. Includes the assertion name, message, filename, and line number.
--- - `"lifecycle"`: A lifecycle hook threw an error. Includes the hook name, message, filename, and line number.
--- - `"runtime_error"`: The test body threw an unhandled error. Includes the message and stack trace.
export type Failure =
	{
		assertion: string, -- name of the assertion
		msg: string, -- failure message
		filename: string, -- filename
		linenumber: number, -- linenumber
		__tag: "assertion",
	}
	| {
		hook: Hook, -- the name of the hook that broke
		msg: string, -- failure message
		filename: string, -- filename
		linenumber: number, -- linenumber
		__tag: "lifecycle",
	}
	| {
		msg: string, -- failure message
		stacktrace: string, -- stacktrace
		__tag: "runtime_error",
	}

--- The assertion functions passed to each test case. Each assertion returns a `Failure` on failure, or `nil` on success.
export type NegatedAsserts = {
	eq: <T>(T, T, string?) -> Failure?,
	throws: <T...>((T...) -> ...unknown, T...) -> Failure?,
	throwsWith: <T...>(any, (T...) -> ...unknown, T...) -> Failure?,
	strContains: (string, string, number?, string?) -> Failure?,
	that: (unknown, string?) -> Failure?,
}

export type Asserts = {
	eq: <T>(T, T, string?) -> Failure?,
	neq: <T>(T, T, string?) -> Failure?,
	throws: <T...>((T...) -> ...unknown, T...) -> Failure?,
	throwsWith: <T...>(any, (T...) -> ...unknown, T...) -> Failure?,
	strContains: (string, string, number?, string?) -> Failure?,
	strNotContains: (string, string, string?) -> Failure?,
	that: (unknown, string?) -> Failure?,
	never: NegatedAsserts,
}

--- A test function that receives the assertion helpers and runs one test case.
export type Test = (Asserts) -> ()

--- A named test case pairing a name with its test function.
export type TestCase = { name: string, case: Test }

--- A named collection of test cases with optional lifecycle hooks.
export type TestSuite = {
	name: string,
	cases: { TestCase },
	_beforeEach: (() -> ())?,
	_beforeAll: (() -> ())?,
	_afterEach: (() -> ())?,
	_afterAll: (() -> ())?,
	case: (self: TestSuite, string, Test) -> (),
	beforeEach: (self: TestSuite, () -> ()) -> (),
	beforeAll: (self: TestSuite, () -> ()) -> (),
	afterEach: (self: TestSuite, () -> ()) -> (),
	afterAll: (self: TestSuite, () -> ()) -> (),
}

-- Additional options for configuring the test runner
export type TestRunnerOptions = {
	verbose: boolean,
}

--- A test case that failed, paired with the failure that caused it.
export type FailedTest = {
	test: string, -- name of the test case that failed
	failure: Failure,
}

--- The aggregate results of a test run: total, passed, failed counts and the list of failures.
export type TestRunResult = {
	failures: { FailedTest },
	total: number,
	failed: number,
	passed: number,
}

--- A function that receives a `TestRunResult` and reports it (e.g. prints to stdout).
export type TestReporter = (TestRunResult) -> ()

-- Testing Environment
--- An index entry mapping a test case name to all anonymous instances and suite instances with that name.
export type CaseIndexEntry = {
	anonymous: { TestCase },
	suites: { [string]: { TestCase } },
}

--- The full set of discovered tests: anonymous cases, suites, and lookup indexes by name.
export type TestEnvironment = {
	anonymous: { TestCase },
	suites: { TestSuite },
	suiteindex: { [string]: TestSuite },
	caseindex: { [string]: CaseIndexEntry },
}

--- A function that runs a `TestEnvironment` and returns the results.
export type TestRunner = (TestEnvironment, TestRunnerOptions?) -> TestRunResult

return {}
