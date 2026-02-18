# win32

```luau
local win32 = require("@std/path/win32")
```

## win32.basename

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string | nil)
```

## win32.dirname

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string)
```

## win32.drive

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## win32.extname

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string)
```

## win32.format

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string)
```

## win32.isabsolute

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (boolean)
```

## win32.join

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }...) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## win32.normalize

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## win32.parse

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## win32.pathmt

```luau
{ __tostring: (<recursive>) -> (string) }
```

## win32.relative

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## win32.resolve

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }...) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```
