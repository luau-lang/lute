# test

```luau
local test = require("@std/test")
```

## test._registered

```luau
() -> ()
```

## test.case

```luau
(name: string, case: Test) -> ()
```

## test.suite

```luau
(name: string, registerFn: (TestSuite) -> ()) -> ()
```
