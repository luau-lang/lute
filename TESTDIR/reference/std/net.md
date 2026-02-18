# net

```luau
local net = require("@std/net")
```

## net.request

```luau
(string, { headers: { [string]: any } | nil, method: string | nil, body: string | nil } | nil) -> ({ ok: boolean, status: number, headers: { [string]: any }, body: string })
```
