# net

```luau
local net = require("@lute/net")
```

## get
```luau
() -> string
```

## getAsync <Badge type="warning" text="yields" />
```luau
() -> string
```

## serve
```luau
({ hostname: string?, port: number?, handler: RequestHandler } | RequestHandler) -> ServeHandle
```
