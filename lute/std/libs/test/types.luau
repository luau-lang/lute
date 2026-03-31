--!strict
-- @std/test/types
-- Standard test types library for Luau

-- Test Reporting

export type Hook = "beforeeach" | "beforeall" | "aftereach" | "afterall"
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

export type Asserts = {
	eq: <T>(T, T, string?) -> Failure?,
	neq: <T>(T, T, string?) -> Failure?,
	throws: <T...>((T...) -> ...unknown, T...) -> Failure?,
	throwsWith: <T...>(any, (T...) -> ...unknown, T...) -> Failure?,
	strcontains: (string, string, number?, string?) -> Failure?,
	strnotcontains: (string, string, string?) -> Failure?,
	that: (unknown, string?) -> Failure?,
}

export type Test = (Asserts) -> ()

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
	failure: Failure,
}

export type TestRunResult = {
	failures: { FailedTest },
	total: number,
	failed: number,
	passed: number,
}

export type TestReporter = (TestRunResult) -> ()

-- Testing Environment
export type CaseIndexEntry = {
	anonymous: { TestCase },
	suites: { [string]: { TestCase } },
}

export type TestEnvironment = {
	anonymous: { TestCase },
	suites: { TestSuite },
	suiteindex: { [string]: TestSuite },
	caseindex: { [string]: CaseIndexEntry },
}

export type TestRunner = (TestEnvironment) -> TestRunResult

return {}
