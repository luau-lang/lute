# task

```luau
local task = require("@lute/task")
```

## task.defer

```luau
<T..., U...>(routine: (T...) -> (U...) | thread) -> (thread)
```

## task.deferSelf

```luau
() -> (unknown...)
```

## task.delay

```luau
<T..., U...>(dur: number | {}, routine: thread | (T...) -> (U...)) -> (thread)
```

## task.resume

```luau
(thread: thread) -> (thread)
```

## task.spawn

```luau
<T..., U...>(routine: (T...) -> (U...) | thread) -> (thread)
```

## task.wait

```luau
(dur: number | {} | nil) -> (number)
```
