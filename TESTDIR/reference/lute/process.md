# process

```luau
local process = require("@lute/process")
```

## process.args

```lua
{ [number]: any }
```

## process.cwd

```lua
() -> (string)
```

## process.env

```lua
{ [string]: any }
```

## process.execpath

```lua
() -> (string)
```

## process.exit

```lua
(exitcode: number) -> (never)
```

## process.homedir

```lua
() -> (string)
```

## process.run

```lua
(args: { [number]: any }, options: { cwd: string?, env: { [string]: any }?, stdio: "default" | "inherit" | "none"? }?) -> ({ exitcode: number, ok: boolean, signal: string?, stderr: string, stdout: string })
```

## process.system

```lua
(command: string, options: { cwd: string?, env: { [string]: any }?, stdio: "default" | "inherit" | "none"?, system: string? }?) -> ({ exitcode: number, ok: boolean, signal: string?, stderr: string, stdout: string })
```
