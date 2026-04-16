# printer

```luau
local printer = require("@std/syntax/printer")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [printFile](#printerprintfile) | Returns an entire parsed file as source text, including the EOF token, optionally applying `replacements`. |
| [printNode](#printerprintnode) | Returns `node` as source text, optionally applying `replacements` to substitute specific nodes with new text. |

---

## Functions and Properties

### printer.printFile

Returns an entire parsed file as source text, including the EOF token, optionally applying `replacements`.

```luau
(result: types.ParseResult, replacements: types.Replacements?) -> string
```

---

### printer.printNode

Returns `node` as source text, optionally applying `replacements` to substitute specific nodes with new text.

```luau
(node: types.AstNode, replacements: types.Replacements?) -> string
```

---
