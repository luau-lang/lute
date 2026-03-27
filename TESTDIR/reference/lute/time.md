# time

```luau
local time = require("@lute/time")
```

## time.duration

```luau
{ seconds: (seconds: number) -> ({}), microseconds: (microseconds: number) -> ({}), milliseconds: (milliseconds: number) -> ({}), create: (seconds: number, subsecnanos: number) -> ({}), minutes: (minutes: number) -> ({}), nanoseconds: (nanoseconds: number) -> ({}), weeks: (weeks: number) -> ({}), hours: (hours: number) -> ({}), days: (days: number) -> ({}) }
```

## time.now

```luau
() -> ({})
```

## time.since

```luau
(instant: {}) -> (number)
```
