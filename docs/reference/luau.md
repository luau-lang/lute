# luau

```luau
local luau = require("@lute/luau")
```

## compile
```luau
(source: string) -> Bytecode
```

## load
```luau
(bytecode: Bytecode) -> () -> ()
```

## parse
```luau
(source: string) -> AstStatBlock
```

## parseexpr
```luau
(expr: string) -> AstExpr
```
