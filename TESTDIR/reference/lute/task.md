# task

```luau
local task = require("@lute/task")
```

## task.defer

```lua
<T..., U...>(routine: (T...) -> (U...) | thread, T...) -> (thread)
```

## task.deferSelf

```lua
() -> (unknown...)
```

## task.delay

```lua
<T..., U...>(dur: number | {}, routine: (T...) -> (U...) | thread, T...) -> (thread)
```

## task.resume

```lua
(thread: thread) -> (thread)
```

## task.spawn

```lua
<T..., U...>(routine: (T...) -> (U...) | thread, T...) -> (thread)
```

## task.wait

```lua
(dur: number | {}?) -> (number)
```
