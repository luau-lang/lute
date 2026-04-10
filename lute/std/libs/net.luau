--!strict
-- @std/net
-- stdlib for `@lute/net`

local client = require("@lute/net/client")

local netlib = {}

--- Options for an HTTP request:
--- - `method`: The HTTP method (e.g. `"GET"`, `"POST"`). Defaults to `"GET"`.
--- - `body`: The request body as a string. If omitted, no body is sent.
--- - `headers`: A table of HTTP headers to include in the request.
export type Metadata = client.Metadata
--- An HTTP response, containing status, headers, and body.
export type Response = client.Response

--- Makes an HTTP request to `url` with optional request metadata. Returns the response.
function netlib.request(url: string, metadata: Metadata?): Response
	return client.request(url, metadata)
end

return table.freeze(netlib)
