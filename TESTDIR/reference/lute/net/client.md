# client

```luau
local client = require("@lute/net/client")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [request](#clientrequest) |  |

---

## Types

### Metadata
```luau
type Metadata = { body: string?, headers: { [string]: any }?, method: string? }
```

### Response
```luau
type Response = { body: string, headers: { [string]: any }, ok: boolean, status: number }
```

## client.request
```luau
function request(url: string, metadata: { body: string?, headers: { [string]: any }?, method: string? }?) -> ({ body: string, headers: { [string]: any }, ok: boolean, status: number })
```
---
