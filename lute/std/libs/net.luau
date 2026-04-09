--!strict
-- @std/net
-- stdlib for `@lute/net`

local client = require("@lute/net/client")

local netlib = {}

--- Metadata for an HTTP request, such as method, headers, and body.
export type Metadata = client.Metadata
--- An HTTP response, containing status, headers, and body.
export type Response = client.Response

--- Makes an HTTP request to `url` with optional request metadata. Returns the response.
function netlib.request(url: string, metadata: Metadata?): Response
	return client.request(url, metadata)
end

return table.freeze(netlib)
