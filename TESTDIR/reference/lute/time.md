# time

```luau
local time = require("@lute/time")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [duration](#timeduration) |  |
| [now](#timenow) |  |
| [since](#timesince) |  |

---

## Types

### Duration
```luau
type Duration = {}
```

### Instant
```luau
type Instant = {}
```

## Properties and Functions

## time.duration
```luau
function duration{ create: (seconds: number, subsecnanos: number) -> ({}), days: (days: number) -> ({}), hours: (hours: number) -> ({}), microseconds: (microseconds: number) -> ({}), milliseconds: (milliseconds: number) -> ({}), minutes: (minutes: number) -> ({}), nanoseconds: (nanoseconds: number) -> ({}), seconds: (seconds: number) -> ({}), weeks: (weeks: number) -> ({}) }
```
---

## time.now
```luau
function now() -> ({})
```
---

## time.since
```luau
function since(instant: {}) -> (number)
```
---
