--!strict
-- @std/net
-- stdlib for `@lute/net`

local client = require("@lute/net/client")

local netlib = {}

export type Metadata = client.Metadata
export type Response = client.Response

function netlib.request(url: string, metadata: Metadata?): Response
	return client.request(url, metadata)
end

return table.freeze(netlib)
