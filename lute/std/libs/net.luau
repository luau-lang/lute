--!strict
-- @std/net
-- stdlib for `@lute/net`

local net = require("@lute/net")

local netlib = {}

export type Metadata = net.Metadata
export type Response = net.Response

function netlib.request(url: string, metadata: Metadata?): Response
	return net.request(url, metadata)
end

return table.freeze(netlib)
