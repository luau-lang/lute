--!strict
-- @std/net
-- stdlib for `@lute/net`

local net = require("@lute/net")

local netlib = {}

export type metadata = net.Metadata
export type response = net.Response

function netlib.request(url: string, metadata: metadata?): response
	return net.request(url, metadata)
end

return table.freeze(netlib)
