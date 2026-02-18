# net

```luau
local net = require("@lute/net")
```

## net.request

```luau
(string, { headers: { [string]: any } | nil, method: string | nil, body: string | nil } | nil) -> ({ ok: boolean, status: number, headers: { [string]: any }, body: string })
```

## net.serve

```luau
(({ path: string, method: string, query: { [string]: any }, headers: { [string]: any }, body: string }) -> (string | { status: number | nil, headers: { [string]: any } | nil, body: string | nil }) | { tls: { passphrase: string | nil, keyfilename: string, cafilename: string | nil, certfilename: string } | nil, port: number | nil, hostname: string | nil, reuseport: boolean | nil, handler: ({ path: string, method: string, query: { [string]: any }, headers: { [string]: any }, body: string }) -> (string | { status: number | nil, headers: { [string]: any } | nil, body: string | nil }) }) -> ({ port: number, hostname: string, close: () -> () })
```
