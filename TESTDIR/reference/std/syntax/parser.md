# parser

```luau
local parser = require("@std/syntax/parser")
```

## parser.parse

```luau
(source: string) -> types.ParseResult
```

## parser.parseBlock

Parses Luau source code into an AstStatBlock

```luau
(source: string) -> types.AstStatBlock
```

## parser.parseExpr

```luau
(source: string) -> types.AstExpr
```
