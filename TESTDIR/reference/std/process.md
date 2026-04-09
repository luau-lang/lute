# process

```luau
local process = require("@std/process")
```

## process.cwd

```luau
() -> Path
```

## process.execPath

```luau
() -> Path
```

## process.exit

```luau
(exitcode: number) -> never
```

## process.homedir

```luau
() -> Path
```

## process.run

```luau
(args: { string }, options: ProcessRunOptions?) -> ProcessResult
```

## process.system

```luau
(command: string, options: ProcessSystemOptions?) -> ProcessResult
```
