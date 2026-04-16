# types

```luau
local types = require("@std/test/types")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [Asserts](#asserts) | The assertion functions passed to each test case. Each assertion returns a `Failure` on failure, or `nil` on success. |
| [CaseIndexEntry](#caseindexentry) | An index entry mapping a test case name to all anonymous instances and suite instances with that name. |
| [FailedTest](#failedtest) | A test case that failed, paired with the failure that caused it. |
| [Failure](#failure) | Describes why a test failed: |
| [Hook](#hook) | The name of a lifecycle hook that can run around test cases: |
| [Test](#test) | A test function that receives the assertion helpers and runs one test case. |
| [TestCase](#testcase) | A named test case pairing a name with its test function. |
| [TestEnvironment](#testenvironment) | The full set of discovered tests: anonymous cases, suites, and lookup indexes by name. |
| [TestReporter](#testreporter) | A function that receives a `TestRunResult` and reports it (e.g. prints to stdout). |
| [TestRunResult](#testrunresult) | The aggregate results of a test run: total, passed, failed counts and the list of failures. |
| [TestRunner](#testrunner) | A function that runs a `TestEnvironment` and returns the results. |
| [TestSuite](#testsuite) | A named collection of test cases with optional lifecycle hooks. |

---

## Types

### Asserts

The assertion functions passed to each test case. Each assertion returns a `Failure` on failure, or `nil` on success.

```luau
type Asserts = {
	eq: <T>(T, T, string?) -> Failure?,
	neq: <T>(T, T, string?) -> Failure?,
	throws: <T...>((T...) -> ...unknown, T...) -> Failure?,
	throwsWith: <T...>(any, (T...) -> ...unknown, T...) -> Failure?,
	strContains: (string, string, number?, string?) -> Failure?,
	strNotContains: (string, string, string?) -> Failure?,
	that: (unknown, string?) -> Failure?,
}
```

---

### CaseIndexEntry

An index entry mapping a test case name to all anonymous instances and suite instances with that name.

```luau
type CaseIndexEntry = {
	anonymous: { TestCase },
	suites: { [string]: { TestCase } },
}
```

---

### FailedTest

A test case that failed, paired with the failure that caused it.

```luau
type FailedTest = {
	test: string, -- name of the test case that failed
	failure: Failure,
}
```

---

### Failure

Describes why a test failed:

- `"assertion"`: An assertion (e.g. `t.eq`) failed. Includes the assertion name, message, filename, and line number.

- `"lifecycle"`: A lifecycle hook threw an error. Includes the hook name, message, filename, and line number.

- `"runtime_error"`: The test body threw an unhandled error. Includes the message and stack trace.

```luau
type Failure = 
```

---

### Hook

The name of a lifecycle hook that can run around test cases:

- `"beforeEach"`: Runs before each test case in the suite.

- `"beforeAll"`: Runs once before all test cases in the suite.

- `"afterEach"`: Runs after each test case in the suite.

- `"afterAll"`: Runs once after all test cases in the suite.

```luau
type Hook = "beforeEach" | "beforeAll" | "afterEach" | "afterAll"
```

---

### Test

A test function that receives the assertion helpers and runs one test case.

```luau
type Test = (Asserts) -> ()
```

---

### TestCase

A named test case pairing a name with its test function.

```luau
type TestCase = { name: string, case: Test }
```

---

### TestEnvironment

The full set of discovered tests: anonymous cases, suites, and lookup indexes by name.

```luau
type TestEnvironment = {
	anonymous: { TestCase },
	suites: { TestSuite },
	suiteindex: { [string]: TestSuite },
	caseindex: { [string]: CaseIndexEntry },
}
```

---

### TestReporter

A function that receives a `TestRunResult` and reports it (e.g. prints to stdout).

```luau
type TestReporter = (TestRunResult) -> ()
```

---

### TestRunResult

The aggregate results of a test run: total, passed, failed counts and the list of failures.

```luau
type TestRunResult = {
	failures: { FailedTest },
	total: number,
	failed: number,
	passed: number,
}
```

---

### TestRunner

A function that runs a `TestEnvironment` and returns the results.

```luau
type TestRunner = (TestEnvironment) -> TestRunResult
```

---

### TestSuite

A named collection of test cases with optional lifecycle hooks.

```luau
type TestSuite = {
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
```

---
