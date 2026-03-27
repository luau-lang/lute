# time

```luau
local time = require("@lute/time")
```

## time.duration

```lua
{ create: (seconds: number, subsecnanos: number) -> ({}), days: (days: number) -> ({}), hours: (hours: number) -> ({}), microseconds: (microseconds: number) -> ({}), milliseconds: (milliseconds: number) -> ({}), minutes: (minutes: number) -> ({}), nanoseconds: (nanoseconds: number) -> ({}), seconds: (seconds: number) -> ({}), weeks: (weeks: number) -> ({}) }
```

## time.now

```lua
() -> ({})
```

## time.since

```lua
(instant: {}) -> (number)
```
