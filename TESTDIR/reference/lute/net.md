# net

```luau
local net = require("@lute/net")
```

## net.request

```lua
(url: string, metadata: { body: string?, headers: { [string]: any }?, method: string? }?) -> ({ body: string, headers: { [string]: any }, ok: boolean, status: number })
```

## net.serve

```lua
(config: (request: { body: string, headers: { [string]: any }, method: string, path: string, query: { [string]: any } }) -> (string | { body: string?, headers: { [string]: any }?, status: number? }) | { handler: (request: { body: string, headers: { [string]: any }, method: string, path: string, query: { [string]: any } }) -> (string | { body: string?, headers: { [string]: any }?, status: number? }), hostname: string?, port: number?, reuseport: boolean?, tls: { cafilename: string?, certfilename: string, keyfilename: string, passphrase: string? }? }) -> ({ close: () -> (), hostname: string, port: number })
```
