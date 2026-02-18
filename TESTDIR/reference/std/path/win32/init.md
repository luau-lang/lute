# init

## init.basename

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string | nil)
```

## init.dirname

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string)
```

## init.drive

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## init.extname

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string)
```

## init.format

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string)
```

## init.isabsolute

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (boolean)
```

## init.join

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }...) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## init.normalize

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## init.parse

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## init.pathmt

```luau
{ __tostring: (<recursive>) -> (string) }
```

## init.relative

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```

## init.resolve

```luau
(string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }...) -> ({ kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil })
```
