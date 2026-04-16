# client

```luau
local client = require("@lute/net/client")
```

## Summary

| Entry | Description |
| :--- | :--- |
| [Metadata](#metadata) |  |
| [Response](#response) |  |
| [request](#clientrequest) |  |

---

## Types

### Metadata

```luau
type Metadata = {
	method: string?,
	body: string?,
	headers: { [string]: string }?,
}
```

---

### Response

```luau
type Response = {
	body: string,
	headers: { [string]: string },
	status: number,
	ok: boolean,
}
```

---

## Functions and Properties

### client.request

```luau
(url: string, metadata: Metadata?) -> Response
```

---
