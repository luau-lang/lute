# process

```luau
local process = require("@std/process")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [Path](#path) | A structured, platform-aware file system path. |
| [Pathlike](#pathlike) | Anything that can be used as a path: a string, a `Path`, or raw path data. |
| [ProcessResult](#processresult) | The result of a completed process, including exit code and captured stdout/stderr. |
| [ProcessRunOptions](#processrunoptions) | Options for `process.run`: |
| [ProcessSystemOptions](#processsystemoptions) | Options for `process.system`: |
| [StdioKind](#stdiokind) | How a child process's standard streams should be handled: |
| [cwd](#processcwd) | Returns the current working directory as a `Path`. |
| [execPath](#processexecpath) | Returns the path of the currently running lute executable as a `Path`. |
| [exit](#processexit) | Exits the current process with the given `exitcode`. |
| [homedir](#processhomedir) | Returns the current user's home directory as a `Path`. |
| [run](#processrun) | Runs the program given by `args[1]` with the remaining entries as arguments. |
| [system](#processsystem) | Runs `command` through the system shell. Returns the process result. |

---

## Types

### Path

A structured, platform-aware file system path.

```luau
type Path = pathlib.Path
```

---

### Pathlike

Anything that can be used as a path: a string, a `Path`, or raw path data.

```luau
type Pathlike = pathlib.Pathlike
```

---

### ProcessResult

The result of a completed process, including exit code and captured stdout/stderr.

```luau
type ProcessResult = process.ProcessResult
```

---

### ProcessRunOptions

Options for `process.run`:

- `cwd`: The working directory for the child process. Defaults to the current working directory.

- `stdio`: How to handle the child's stdio streams. Defaults to `"default"`.

- `env`: Environment variables for the child process. If omitted, inherits the parent's environment.

```luau
type ProcessRunOptions = process.ProcessRunOptions
```

---

### ProcessSystemOptions

Options for `process.system`:

- `system`: The shell executable to use. If omitted, uses the platform default (`$SHELL` on Unix, `%COMSPEC%` on Windows).

- `cwd`: The working directory for the child process. Defaults to the current working directory.

- `stdio`: How to handle the child's stdio streams. Defaults to `"default"`.

- `env`: Environment variables for the child process. If omitted, inherits the parent's environment.

```luau
type ProcessSystemOptions = process.ProcessSystemOptions
```

---

### StdioKind

How a child process's standard streams should be handled:

- `"default"`: Capture stdout and stderr to pipes, accessible via `ProcessResult`.

- `"inherit"`: Pass the parent process's stdio streams through to the child.

- `"none"`: Discard the child's stdio streams.

```luau
type StdioKind = process.StdioKind
```

---

## Functions and Properties

### process.cwd

Returns the current working directory as a `Path`.

```luau
() -> Path
```

---

### process.execPath

Returns the path of the currently running lute executable as a `Path`.

```luau
() -> Path
```

---

### process.exit

Exits the current process with the given `exitcode`.

```luau
(exitcode: number) -> never
```

---

### process.homedir

Returns the current user's home directory as a `Path`.

```luau
() -> Path
```

---

### process.run

Runs the program given by `args[1]` with the remaining entries as arguments.

Returns the process result including exit code and any captured output.

```luau
(args: { string }, options: ProcessRunOptions?) -> ProcessResult
```

---

### process.system

Runs `command` through the system shell. Returns the process result.

```luau
(command: string, options: ProcessSystemOptions?) -> ProcessResult
```

---
