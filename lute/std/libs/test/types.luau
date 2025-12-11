--!strict
-- @std/test/types
-- Standard test types library for Luau

-- Test Reporting
local assert = require("./assert")

export type test = (assert.asserts) -> ()

export type testcase = { name: string, case: test }

export type testsuite = {
	name: string,
	cases: { testcase },
	_beforeeach: (() -> ())?,
	_beforeall: (() -> ())?,
	_aftereach: (() -> ())?,
	_afterall: (() -> ())?,
	case: (self: testsuite, string, test) -> (),
	beforeeach: (self: testsuite, () -> ()) -> (),
	beforeall: (self: testsuite, () -> ()) -> (),
	aftereach: (self: testsuite, () -> ()) -> (),
	afterall: (self: testsuite, () -> ()) -> (),
}

export type failedtest = {
	test: string, -- name of the test case that failed
	assertion: string?, -- if an assertion failed, name of the assertion that failed (e.g., "assert.eq")
	error: string?, -- the error message to report with a failed assertion
	filename: string, -- source file where the failure occurred
	linenumber: number, -- line number of the failure
}

export type testrunresult = {
	failures: { failedtest },
	total: number,
	failed: number,
	passed: number,
}

export type testreporter = (testrunresult) -> ()

-- Testing Environment
export type caseindexentry = {
	anonymous: { testcase },
	suites: { [string]: { testcase } },
}

export type testenvironment = {
	anonymous: { testcase },
	suites: { testsuite },
	suiteindex: { [string]: testsuite },
	caseindex: { [string]: caseindexentry },
}

export type testrunner = (testenvironment) -> testrunresult

return {}
