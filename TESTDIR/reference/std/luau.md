# luau

```luau
local luau = require("@std/luau")
```

## luau.compile

```luau
(string) -> ({ bytecode: string })
```

## luau.load

```luau
({ bytecode: string }, string | nil, { [any]: any } | nil) -> ((any...) -> (any...))
```

## luau.loadbypath

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }, { [any]: any } | nil) -> (any)
```

## luau.resolverequire

```luau
(string, string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> (string)
```

## luau.typeofmodule

```luau
(string | { absolute: boolean, parts: { [number]: any } } | { absolute: boolean, parts: { [number]: any } } | string | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil } | { kind: "unc" | "absolute" | "relative", parts: { [number]: any }, drive: string | nil }) -> ({ type: { metatable: <recursive> | nil, genericpacks: { [number]: any }, parent: <recursive> | nil, ispack: boolean, generics: { [number]: any }, parameters: <recursive>, value: string | boolean | nil, indexer: { index: <recursive> } | nil, name: string, returns: <recursive>, inner: <recursive>, properties: { [string]: any }, components: { [number]: any }, tag: "nil" | "unknown" | "never" | "any" | "boolean" | "number" | "string" | "buffer" | "thread" | "singleton" | "negation" | "union" | "intersection" | "table" | "function" | "extern" | "generic" }, name: string, head: { [number]: any } | nil, tail: <recursive> | nil, ispack: boolean, hidden: boolean, tag: "typepack" | "variadic" | "generic" } | nil)
```
