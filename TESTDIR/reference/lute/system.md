# system

```luau
local system = require("@lute/system")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
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
type CpuInfo = { model: string, speed: number, times: { idle: number, irq: number, nice: number, sys: number, user: number } }
```

## Properties and Functions

## system.arch
```luau
string
```
---

## system.cpus
```luau
function cpus() -> ({ [number]: any })
```
---

## system.freeMemory
```luau
function freeMemory() -> (number)
```
---

## system.hostName
```luau
function hostName() -> (string)
```
---

## system.os
```luau
string
```
---

## system.threadCount
```luau
function threadCount() -> (number)
```
---

## system.tmpdir
```luau
function tmpdir() -> (string)
```
---

## system.totalMemory
```luau
function totalMemory() -> (number)
```
---

## system.uptime
```luau
function uptime() -> (number)
```
---
