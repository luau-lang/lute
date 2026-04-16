# process

```luau
local process = require("@lute/process")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [ProcessResult](#processresult) |  |
| [ProcessRunOptions](#processrunoptions) |  |
| [ProcessSystemOptions](#processsystemoptions) |  |
| [StdioKind](#stdiokind) |  |
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
type ProcessResult = {
	stdout: string,
	stderr: string,

	ok: boolean,
	exitcode: number,
	signal: string?,
}
```

---

### ProcessRunOptions

```luau
type ProcessRunOptions = {
	cwd: string?,
	stdio: StdioKind?,

	env: { [string]: string }?,
}
```

---

### ProcessSystemOptions

```luau
type ProcessSystemOptions = {
	system: string?,
	cwd: string?,
	stdio: StdioKind?,

	env: { [string]: string }?,
}
```

---

### StdioKind

```luau
type StdioKind = "default" | "inherit" | "none"
```

---

## Functions and Properties

### process.args

```luau
{ string }
```

---

### process.cwd

```luau
() -> string
```

---

### process.env

```luau
{ [string]: string }
```

---

### process.execPath

```luau
() -> string
```

---

### process.exit

```luau
(exitcode: number) -> never
```

---

### process.homedir

```luau
() -> string
```

---

### process.run

```luau
(args: { string }, options: ProcessRunOptions?) -> ProcessResult
```

---

### process.system

```luau
(command: string, options: ProcessSystemOptions?) -> ProcessResult
```

---
