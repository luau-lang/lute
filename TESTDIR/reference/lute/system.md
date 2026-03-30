# system

```luau
local system = require("@lute/system")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [arch](#systemarch) |  |
| [cpus](#systemcpus) |  |
| [freememory](#systemfreememory) |  |
| [hostname](#systemhostname) |  |
| [os](#systemos) |  |
| [threadcount](#systemthreadcount) |  |
| [tmpdir](#systemtmpdir) |  |
| [totalmemory](#systemtotalmemory) |  |
| [uptime](#systemuptime) |  |

---

## Types

### CpuInfo
```luau
type CpuInfo = { model: string, speed: number, times: { idle: number, irq: number, nice: number, sys: number, user: number } }
```

## system.arch
```luau
function archstring
```
---

## system.cpus
```luau
function cpus() -> ({ [number]: any })
```
---

## system.freememory
```luau
function freememory() -> (number)
```
---

## system.hostname
```luau
function hostname() -> (string)
```
---

## system.os
```luau
function osstring
```
---

## system.threadcount
```luau
function threadcount() -> (number)
```
---

## system.tmpdir
```luau
function tmpdir() -> (string)
```
---

## system.totalmemory
```luau
function totalmemory() -> (number)
```
---

## system.uptime
```luau
function uptime() -> (number)
```
---
