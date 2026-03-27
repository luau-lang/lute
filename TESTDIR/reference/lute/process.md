# process

```luau
local process = require("@lute/process")
```

## process.args

```luau
{ [number]: any }
```

## process.cwd

```luau
() -> (string)
```

## process.env

```luau
{ [string]: any }
```

## process.execpath

```luau
() -> (string)
```

## process.exit

```luau
(exitcode: number) -> (never)
```

## process.homedir

```luau
() -> (string)
```

## process.run

```luau
(args: { [number]: any }, options: { env: { [string]: any } | nil) -> ({ exitcode: number, stderr: string, stdout: string, ok: boolean, signal: string | nil })
```

## process.system

```luau
(command: string, options: { env: { [string]: any } | nil) -> ({ exitcode: number, stderr: string, stdout: string, ok: boolean, signal: string | nil })
```
