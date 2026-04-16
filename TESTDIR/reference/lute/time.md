# time

```luau
local time = require("@lute/time")
```

## Summary

| Entry | Description |
| :--- | :--- |
| [Duration](#duration) |  |
| [Instant](#instant) |  |
| [duration.create](#timedurationcreate) |  |
| [duration.days](#timedurationdays) |  |
| [duration.hours](#timedurationhours) |  |
| [duration.microseconds](#timedurationmicroseconds) |  |
| [duration.milliseconds](#timedurationmilliseconds) |  |
| [duration.minutes](#timedurationminutes) |  |
| [duration.nanoseconds](#timedurationnanoseconds) |  |
| [duration.seconds](#timedurationseconds) |  |
| [duration.weeks](#timedurationweeks) |  |
| [now](#timenow) |  |
| [since](#timesince) |  |

---

## Types

### Duration

```luau
type Duration = setmetatable<Frozen, {
	read __metatable: "The metatable is locked!",
	read __index: typeof(table.freeze(duration_ops)),
	read __add: (Duration, Duration) -> Duration,
	read __sub: (Duration, Duration) -> Duration,
	read __mul: (Duration, number) -> Duration,
	read __div: (Duration, number) -> Duration,
	read __eq: (Duration, Duration) -> boolean,
	read __lt: (Duration, Duration) -> boolean,
	read __le: (Duration, Duration) -> boolean,
}>
```

---

### Instant

```luau
type Instant = setmetatable<Frozen, {
	read __metatable: "The metatable is locked!",
	read __index: typeof(table.freeze(instant)),
	read __sub: (Instant, Instant) -> Duration,
	read __eq: (Instant, Instant) -> boolean,
	read __lt: (Instant, Instant) -> boolean,
	read __le: (Instant, Instant) -> boolean,
}>
```

---

## Functions and Properties

### time.duration.create

```luau
(seconds: number, subsecnanos: number) -> Duration
```

---

### time.duration.days

```luau
(days: number) -> Duration
```

---

### time.duration.hours

```luau
(hours: number) -> Duration
```

---

### time.duration.microseconds

```luau
(microseconds: number) -> Duration
```

---

### time.duration.milliseconds

```luau
(milliseconds: number) -> Duration
```

---

### time.duration.minutes

```luau
(minutes: number) -> Duration
```

---

### time.duration.nanoseconds

```luau
(nanoseconds: number) -> Duration
```

---

### time.duration.seconds

```luau
(seconds: number) -> Duration
```

---

### time.duration.weeks

```luau
(weeks: number) -> Duration
```

---

### time.now

```luau
() -> Instant
```

---

### time.since

```luau
(instant: Instant) -> number
```

---
