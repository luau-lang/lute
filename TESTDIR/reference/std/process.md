# process

```luau
local process = require("@std/process")
```

## process.cwd

```luau
() -> ({ absolute: boolean, parts: { [number]: any } } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## process.env

```luau
{ [string]: any }
```

## process.execpath

```luau
() -> ({ absolute: boolean, parts: { [number]: any } } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## process.exit

```luau
(number) -> (never)
```

## process.homedir

```luau
() -> ({ absolute: boolean, parts: { [number]: any } } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## process.run

```luau
({ [number]: any }, { env: { [string]: any } | nil, cwd: string | nil, stdio: "default" | "inherit" | "none" | nil } | nil) -> ({ exitcode: number, stderr: string, stdout: string, ok: boolean, signal: string | nil })
```

## process.system

```luau
(string, { env: { [string]: any } | nil, cwd: string | nil, stdio: "default" | "inherit" | "none" | nil, system: string | nil } | nil) -> ({ exitcode: number, stderr: string, stdout: string, ok: boolean, signal: string | nil })
```
