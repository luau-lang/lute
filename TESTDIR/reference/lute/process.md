# process

```luau
local process = require("@lute/process")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [execpath](#processexecpath) |  |
| [cwd](#processcwd) |  |
| [exit](#processexit) |  |
| [args](#processargs) |  |
| [env](#processenv) |  |
| [run](#processrun) |  |
| [homedir](#processhomedir) |  |
| [system](#processsystem) |  |

---

## process.execpath
```luau
function execpath() -> (string)
```

---

## process.cwd
```luau
function cwd() -> (string)
```

---

## process.exit
```luau
function exit(exitcode: number) -> (never)
```

---

## process.args
```luau
function args{ [number]: any }
```

---

## process.env
```luau
function env{ [string]: any }
```

---

## process.run
```luau
function run(args: { [number]: any }, options: { cwd: string?, env: { [string]: any }?, stdio: "default" | "inherit" | "none"? }?) -> ({ exitcode: number, ok: boolean, signal: string?, stderr: string, stdout: string })
```

---

## process.homedir
```luau
function homedir() -> (string)
```

---

## process.system
```luau
function system(command: string, options: { cwd: string?, env: { [string]: any }?, stdio: "default" | "inherit" | "none"?, system: string? }?) -> ({ exitcode: number, ok: boolean, signal: string?, stderr: string, stdout: string })
```

---
