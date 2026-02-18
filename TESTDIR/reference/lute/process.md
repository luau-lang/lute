# process

```luau
local process = require("@lute/process")
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
(number) -> (never)
```

## process.homedir

```luau
() -> (string)
```

## process.run

```luau
({ [number]: any }, { env: { [string]: any } | nil, cwd: string | nil, stdio: "default" | "inherit" | "none" | nil } | nil) -> ({ exitcode: number, stderr: string, stdout: string, ok: boolean, signal: string | nil })
```

## process.system

```luau
(string, { env: { [string]: any } | nil, cwd: string | nil, stdio: "default" | "inherit" | "none" | nil, system: string | nil } | nil) -> ({ exitcode: number, stderr: string, stdout: string, ok: boolean, signal: string | nil })
```
