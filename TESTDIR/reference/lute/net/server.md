# server

```luau
local server = require("@lute/net/server")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [Configuration](#configuration) |  |
| [Handler](#handler) |  |
| [ReceivedRequest](#receivedrequest) |  |
| [Server](#server) |  |
| [ServerResponse](#serverresponse) |  |
| [serve](#serverserve) |  |

---

## Types

### Configuration

```luau
type Configuration = {
	hostname: string?,
	port: number?,
	reuseport: boolean?,
	tls: { certfilename: string, keyfilename: string, passphrase: string?, cafilename: string? }?,
	handler: Handler,
}
```

---

### Handler

```luau
type Handler = (request: ReceivedRequest) -> ServerResponse
```

---

### ReceivedRequest

```luau
type ReceivedRequest = {
	method: string,
	path: string,
	body: string,
	query: { [string]: string },
	headers: { [string]: string },
}
```

---

### Server

```luau
type Server = {
	hostname: string,
	port: number,
	close: () -> (),
}
```

---

### ServerResponse

```luau
type ServerResponse = string | {
	status: number?,
	body: string?,
	headers: { [string]: string }?,
}
```

---

## Functions and Properties

### server.serve

```luau
(config: Handler | Configuration) -> Server
```

---
