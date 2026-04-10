# task

```luau
local task = require("@lute/task")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [defer](#taskdefer) |  |
| [deferSelf](#taskdeferself) |  |
| [delay](#taskdelay) |  |
| [resume](#taskresume) |  |
| [spawn](#taskspawn) |  |
| [wait](#taskwait) |  |

---

## Properties and Functions

## task.defer
```luau
function defer<T..., U...>(routine: (T...) -> (U...) | thread, T...) -> (thread)
```
---

## task.deferSelf
```luau
function deferSelf() -> (unknown...)
```
---

## task.delay
```luau
function delay<T..., U...>(dur: number | {}, routine: (T...) -> (U...) | thread, T...) -> (thread)
```
---

## task.resume
```luau
function resume(thread: thread) -> (thread)
```
---

## task.spawn
```luau
function spawn<T..., U...>(routine: (T...) -> (U...) | thread, T...) -> (thread)
```
---

## task.wait
```luau
function wait(dur: number | {}?) -> (number)
```
---
