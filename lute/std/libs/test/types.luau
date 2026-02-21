--!strict
-- @std/test/types
-- Standard test types library for Luau

-- Test Reporting

export type hook = "beforeeach" | "beforeall" | "aftereach" | "afterall"
export type failure =
	{
		assertion: string, -- name of the assertion
		msg: string, -- failure message
		filename: string, -- filename
		linenumber: number, -- linenumber
		__tag: "assertion",
	}
	| {
		hook: hook, -- the name of the hook that broke
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

export type asserts = {
	eq: <T>(T, T, string?) -> failure?,
	neq: <T>(T, T, string?) -> failure?,
	errors: (() -> (), string?) -> failure?,
	-- FIXME(Luau): We would like this to be two read-only indexers, but the
	-- best option we have otherwise is two error suppressing indexers.
	tableeq: ({ [any]: any }, { [any]: any }) -> failure?,
	buffereq: (buffer, buffer) -> failure?,
	erroreq: <A...>((A...) -> ...unknown, string, A...) -> failure?,
	strcontains: (string, string, string?, number?) -> failure?,
	strnotcontains: (string, string, string?) -> failure?,
}

export type test = (asserts) -> ()

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
	failure: failure,
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
