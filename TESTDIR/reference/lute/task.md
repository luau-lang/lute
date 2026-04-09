# task

```luau
local task = require("@lute/task")
```

## task.defer

```luau
(routine: ((T...) -> U...) | thread, ...: T...) -> thread
```

## task.deferSelf

```luau
() -> ()
```

## task.delay

```luau
(dur: number | time.Duration, routine: thread | ((T...) -> U...), ...: T...) -> thread
```

## task.resume

```luau
(thread: thread) -> thread
```

## task.spawn

```luau
(routine: ((T...) -> U...) | thread, ...: T...) -> thread
```

## task.wait

```luau
(dur: (number | time.Duration)?) -> number
```
