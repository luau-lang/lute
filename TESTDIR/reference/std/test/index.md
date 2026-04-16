# test

```luau
local test = require("@std/test")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [_registered](#testregistered) |  |
| [case](#testcase) | Registers an anonymous (top-level) test case with the given `name`. |
| [suite](#testsuite) | Registers a test suite with `name`, using `registerFn` to define its test cases. |

---

## Functions and Properties

### test._registered

```luau
() -> ()
```

---

### test.case

Registers an anonymous (top-level) test case with the given `name`.

```luau
(name: string, case: Test) -> ()
```

---

### test.suite

Registers a test suite with `name`, using `registerFn` to define its test cases.

```luau
(name: string, registerFn: (TestSuite) -> ()) -> ()
```

---
