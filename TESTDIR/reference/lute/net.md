# net

```luau
local net = require("@lute/net")
```

## net.request

```luau
(url: string, metadata: { headers: { [string]: any } | nil) -> ({ ok: boolean, status: number, headers: { [string]: any }, body: string })
```

## net.serve

```luau
(config: (request: { path: string) -> (string | { status: number | nil) -> ({ port: number, hostname: string, close: () -> () })
```
