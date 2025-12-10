--!strict
-- @std/net
-- stdlib for `@lute/net`

local luteNet = require("@lute/net")

local net = {}

export type metadata = luteNet.Metadata
export type response = luteNet.Response

function net.request(url: string, metadata: metadata?): response
	return luteNet.request(url, metadata)
end

return net
