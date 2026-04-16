# runner

```luau
local runner = require("@std/test/runner")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [run](#runnerrun) | Runs all test cases and suites in `env`, executing lifecycle hooks around each case. Returns the aggregate results. |
| [runRegisteredTests](#runnerrunregisteredtests) | Runs all globally registered tests, prints the results with the simple reporter, then exits the process with code 0 on success or 1 on failure. |

---

## Functions and Properties

### runner.run

Runs all test cases and suites in `env`, executing lifecycle hooks around each case. Returns the aggregate results.

```luau
(env: TestEnvironment) -> TestRunResult
```

---

### runner.runRegisteredTests

Runs all globally registered tests, prints the results with the simple reporter, then exits the process with code 0 on success or 1 on failure.

```luau
() -> ()
```

---
