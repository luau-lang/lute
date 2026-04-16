# system

```luau
local system = require("@lute/system")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [CpuInfo](#cpuinfo) |  |
| [arch](#systemarch) |  |
| [cpus](#systemcpus) |  |
| [freeMemory](#systemfreememory) |  |
| [hostName](#systemhostname) |  |
| [os](#systemos) |  |
| [threadCount](#systemthreadcount) |  |
| [tmpdir](#systemtmpdir) |  |
| [totalMemory](#systemtotalmemory) |  |
| [uptime](#systemuptime) |  |

---

## Types

### CpuInfo

```luau
type CpuInfo = {
	model: string,
	speed: number,

	times: {
		sys: number,
		idle: number,
		irq: number,
		nice: number,
		user: number,
	},
}
```

---

## Functions and Properties

### system.arch

```luau
string
```

---

### system.cpus

```luau
() -> { CpuInfo }
```

---

### system.freeMemory

```luau
() -> number
```

---

### system.hostName

```luau
() -> string
```

---

### system.os

```luau
string
```

---

### system.threadCount

```luau
() -> number
```

---

### system.tmpdir

```luau
() -> string
```

---

### system.totalMemory

```luau
() -> number
```

---

### system.uptime

```luau
() -> number
```

---
