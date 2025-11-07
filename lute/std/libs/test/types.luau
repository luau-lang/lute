--!strict
-- @std/test/types
-- Standard test types library for Luau

-- Test Reporting
local assert = require("./assert")

export type Test = (assert.Asserts) -> ()

export type TestCase = { name: string, case: Test }

export type TestSuite = {
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

export type FailedTest = {
	test: string, -- name of the test case that failed
	assertion: string?, -- if an assertion failed, name of the assertion that failed (e.g., "assert.eq")
	message: string?, -- the error message to report with a failed assertion
	filename: string, -- source file where the failure occurred
	linenumber: number, -- line number of the failure
}

export type TestRunResult = {
	failures: { FailedTest },
	total: number,
	failed: number,
	passed: number,
}

export type TestReporter = (TestRunResult) -> ()

-- Testing Environment
export type TestEnvironment = {
	anonymous: { TestCase },
	suites: { TestSuite },
	reporter: TestReporter,
}

export type TestRunner = (TestEnvironment) -> TestRunResult

return {}
