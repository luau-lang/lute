# process

```luau
local process = require("@lute/process")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [args](#processargs) |  |
| [cwd](#processcwd) |  |
| [env](#processenv) |  |
| [execPath](#processexecpath) |  |
| [exit](#processexit) |  |
| [homedir](#processhomedir) |  |
| [run](#processrun) |  |
| [system](#processsystem) |  |

---

## Types

### ProcessResult
```luau
type ProcessResult = { exitcode: number, ok: boolean, signal: string?, stderr: string, stdout: string }
```

### ProcessRunOptions
```luau
type ProcessRunOptions = { cwd: string?, env: { [string]: any }?, stdio: "default" | "inherit" | "none"? }
```

### ProcessSystemOptions
```luau
type ProcessSystemOptions = { cwd: string?, env: { [string]: any }?, stdio: "default" | "inherit" | "none"?, system: string? }
```

### StdioKind
```luau
type StdioKind = "default" | "inherit" | "none"
```

## Properties and Functions

## process.args
```luau
{ [number]: any }
```
---

## process.cwd
```luau
function cwd() -> (string)
```
---

## process.env
```luau
{ [string]: any }
```
---

## process.execPath
```luau
function execPath() -> (string)
```
---

## process.exit
```luau
function exit(exitcode: number) -> (never)
```
---

## process.homedir
```luau
function homedir() -> (string)
```
---

## process.run
```luau
function run(args: { [number]: any }, options: ProcessRunOptions?) -> (ProcessResult)
```
---

## process.system
```luau
function system(command: string, options: ProcessSystemOptions?) -> (ProcessResult)
```
---
