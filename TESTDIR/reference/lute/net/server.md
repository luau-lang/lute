# server

```luau
local server = require("@lute/net/server")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [serve](#serverserve) |  |

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

### ReceivedRequest
```luau
type ReceivedRequest = { body: string, headers: { [string]: any }, method: string, path: string, query: { [string]: any } }
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

## server.serve
```luau
function serve(config: Handler | Configuration) -> (Server)
```
---
