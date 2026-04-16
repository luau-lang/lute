# task

```luau
local task = require("@lute/task")
```

## Summary

| Entry | Description |
| :--- | :--- |
| [defer](#taskdefer) |  |
| [deferSelf](#taskdeferself) |  |
| [delay](#taskdelay) |  |
| [resume](#taskresume) |  |
| [spawn](#taskspawn) |  |
| [wait](#taskwait) |  |

---

## Functions and Properties

### task.defer

```luau
(routine: ((T...) -> U...) | thread, ...: T...) -> thread
```

---

### task.deferSelf

```luau
() -> ()
```

---

### task.delay

```luau
(dur: number | time.Duration, routine: thread | ((T...) -> U...), ...: T...) -> thread
```

---

### task.resume

```luau
(thread: thread) -> thread
```

---

### task.spawn

```luau
(routine: ((T...) -> U...) | thread, ...: T...) -> thread
```

---

### task.wait

```luau
(dur: (number | time.Duration)?) -> number
```

---
