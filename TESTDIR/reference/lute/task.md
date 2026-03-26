# task

```luau
local task = require("@lute/task")
```

## task.defer

```luau
<T..., U...>((T...) -> (U...) | thread, T...) -> (thread)
```

## task.deferSelf

```luau
() -> (unknown...)
```

## task.delay

```luau
<T..., U...>(number | {}, thread | (T...) -> (U...), T...) -> (thread)
```

## task.resume

```luau
(thread) -> (thread)
```

## task.spawn

```luau
<T..., U...>((T...) -> (U...) | thread, T...) -> (thread)
```

## task.wait

```luau
(number | {} | nil) -> (number)
```
