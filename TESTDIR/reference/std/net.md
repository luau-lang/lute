# net

```luau
local net = require("@std/net")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [Metadata](#metadata) | Options for an HTTP request: |
| [Response](#response) | An HTTP response, containing status, headers, and body. |

---

## Types

### Metadata

Options for an HTTP request:

- `method`: The HTTP method (e.g. `"GET"`, `"POST"`). Defaults to `"GET"`.

- `body`: The request body as a string. If omitted, no body is sent.

- `headers`: A table of HTTP headers to include in the request.

```luau
type Metadata = client.Metadata
```

---

### Response

An HTTP response, containing status, headers, and body.

```luau
type Response = client.Response
```

---
