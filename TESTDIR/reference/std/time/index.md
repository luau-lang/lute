# time

```luau
local time = require("@std/time")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [Duration](#duration) | A span of time. |
| [Instant](#instant) | An opaque point in time, used with `time.since` to measure elapsed time. |
| [now](#timenow) | Returns the current point in time as an `Instant`. |
| [since](#timesince) | Returns the number of seconds elapsed since `instant`. |

---

## Types

### Duration

A span of time.

```luau
type Duration = duration.Duration
```

---

### Instant

An opaque point in time, used with `time.since` to measure elapsed time.

```luau
type Instant = luteTime.Instant
```

---

## Functions and Properties

### time.now

Returns the current point in time as an `Instant`.

```luau
() -> Instant
```

---

### time.since

Returns the number of seconds elapsed since `instant`.

```luau
(instant: Instant) -> number
```

---
