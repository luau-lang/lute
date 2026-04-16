# duration

```luau
local duration = require("@std/time/duration")
```

## Summary

| Entry | Description |
| :--- | :--- |
| [Duration](#duration) | A span of time. |
| [create](#durationcreate) | Creates a `Duration` from a number of `seconds` and an additional number of nanoseconds, `subsecnanos`. |
| [days](#durationdays) | Creates a `Duration` from a number of days. |
| [hours](#durationhours) | Creates a `Duration` from a number of hours. |
| [microseconds](#durationmicroseconds) | Creates a `Duration` from a number of microseconds. |
| [milliseconds](#durationmilliseconds) | Creates a `Duration` from a number of milliseconds. |
| [minutes](#durationminutes) | Creates a `Duration` from a number of minutes. |
| [nanoseconds](#durationnanoseconds) | Creates a `Duration` from a number of nanoseconds. |
| [seconds](#durationseconds) | Creates a `Duration` from a number of seconds. |
| [weeks](#durationweeks) | Creates a `Duration` from a number of weeks. |

---

## Types

### Duration

A span of time.

```luau
type Duration = time.Duration
```

---

## Functions and Properties

### duration.create

Creates a `Duration` from a number of `seconds` and an additional number of nanoseconds, `subsecnanos`.

```luau
(seconds: number, subsecnanos: number) -> Duration
```

---

### duration.days

Creates a `Duration` from a number of days.

```luau
(days: number) -> Duration
```

---

### duration.hours

Creates a `Duration` from a number of hours.

```luau
(hours: number) -> Duration
```

---

### duration.microseconds

Creates a `Duration` from a number of microseconds.

```luau
(microseconds: number) -> Duration
```

---

### duration.milliseconds

Creates a `Duration` from a number of milliseconds.

```luau
(milliseconds: number) -> Duration
```

---

### duration.minutes

Creates a `Duration` from a number of minutes.

```luau
(minutes: number) -> Duration
```

---

### duration.nanoseconds

Creates a `Duration` from a number of nanoseconds.

```luau
(nanoseconds: number) -> Duration
```

---

### duration.seconds

Creates a `Duration` from a number of seconds.

```luau
(seconds: number) -> Duration
```

---

### duration.weeks

Creates a `Duration` from a number of weeks.

```luau
(weeks: number) -> Duration
```

---
