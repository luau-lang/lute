# net

```luau
local net = require("@lute/net")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [request](#netrequest) |  |
| [serve](#netserve) |  |

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

## net.request
```luau
function request(url: string, metadata: { body: string?, headers: { [string]: any }?, method: string? }?) -> ({ body: string, headers: { [string]: any }, ok: boolean, status: number })
```
---

## net.serve
```luau
function serve(config: (request: { body: string, headers: { [string]: any }, method: string, path: string, query: { [string]: any } }) -> (string | { body: string?, headers: { [string]: any }?, status: number? }) | { handler: (request: { body: string, headers: { [string]: any }, method: string, path: string, query: { [string]: any } }) -> (string | { body: string?, headers: { [string]: any }?, status: number? }), hostname: string?, port: number?, reuseport: boolean?, tls: { cafilename: string?, certfilename: string, keyfilename: string, passphrase: string? }? }) -> ({ close: () -> (), hostname: string, port: number })
```
---
