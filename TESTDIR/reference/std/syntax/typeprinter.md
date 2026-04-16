# typeprinter

```luau
local typeprinter = require("@std/syntax/typeprinter")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [renderType](#typeprinterrendertype) |  |

---

## Properties and Functions

## typeprinter.renderType
```luau
function renderType(t: { argnames: { [number]: any }, components: { [number]: any }, genericpacks: { [number]: any }, generics: { [number]: any }, indexer: { index: t1 }?, inner: t1, ispack: boolean, metatable: t1?, name: string, parameters: { head: { [number]: any }?, hidden: boolean, ispack: boolean, name: string, tag: "generic" | "typepack" | "variadic", tail: t2?, type: t1 }, parent: t1?, properties: { [string]: any }, returns: { head: { [number]: any }?, hidden: boolean, ispack: boolean, name: string, tag: "generic" | "typepack" | "variadic", tail: t3?, type: t1 }, tag: "any" | "boolean" | "buffer" | "extern" | "function" | "generic" | "intersection" | "negation" | "never" | "nil" | "number" | "singleton" | "string" | "table" | "thread" | "union" | "unknown", value: (boolean | string)? }) -> (string)
```
---
