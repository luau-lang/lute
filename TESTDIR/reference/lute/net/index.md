# net

```luau
local net = require("@lute/net")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [client](#netclient) |  |
| [server](#netserver) |  |

---

## Types

### Configuration
```luau
type Configuration = { handler: (request: { body: string, headers: { [string]: any }, method: string, path: string, query: { [string]: any } }) -> (string | { body: string?, headers: { [string]: any }?, status: number? }), hostname: string?, port: number?, reuseport: boolean?, tls: { cafilename: string?, certfilename: string, keyfilename: string, passphrase: string? }? }
```

### Handler
```luau
type Handler = (request: { body: string, headers: { [string]: any }, method: string, path: string, query: { [string]: any } }) -> (string | { body: string?, headers: { [string]: any }?, status: number? })
```

### Metadata
```luau
type Metadata = { body: string?, headers: { [string]: any }?, method: string? }
```

### ReceivedRequest
```luau
type ReceivedRequest = { body: string, headers: { [string]: any }, method: string, path: string, query: { [string]: any } }
```

### Response
```luau
type Response = { body: string, headers: { [string]: any }, ok: boolean, status: number }
```

### Server
```luau
type Server = { close: () -> (), hostname: string, port: number }
```

### ServerResponse
```luau
type ServerResponse = string | { body: string?, headers: { [string]: any }?, status: number? }
```

## Properties and Functions

## net.client
```luau
function client{ request: (url: string, metadata: Metadata?) -> (Response) }
```
---

## net.server
```luau
function server{ serve: (config: Handler | Configuration) -> (Server) }
```
---
