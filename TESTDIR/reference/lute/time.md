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
function duration{ create: (seconds: number, subsecnanos: number) -> (Duration), days: (days: number) -> (Duration), hours: (hours: number) -> (Duration), microseconds: (microseconds: number) -> (Duration), milliseconds: (milliseconds: number) -> (Duration), minutes: (minutes: number) -> (Duration), nanoseconds: (nanoseconds: number) -> (Duration), seconds: (seconds: number) -> (Duration), weeks: (weeks: number) -> (Duration) }
```
---

## time.now
```luau
function now() -> (Duration)
```
---

## time.since
```luau
function since(instant: Duration) -> (number)
```
---
