# parser

```luau
local parser = require("@std/syntax/parser")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [parse](#parserparse) | Parses `source` as a complete Luau file and returns the full `ParseResult`, including the root block and EOF token. |
| [parseBlock](#parserparseblock) | Parses Luau source code into an AstStatBlock |
| [parseExpr](#parserparseexpr) | Parses `source` as a single Luau expression and returns the resulting `AstExpr`. |

---

## Functions and Properties

### parser.parse

Parses `source` as a complete Luau file and returns the full `ParseResult`, including the root block and EOF token.

```luau
(source: string) -> types.ParseResult
```

---

### parser.parseBlock

Parses Luau source code into an AstStatBlock

```luau
(source: string) -> types.AstStatBlock
```

---

### parser.parseExpr

Parses `source` as a single Luau expression and returns the resulting `AstExpr`.

```luau
(source: string) -> types.AstExpr
```

---
