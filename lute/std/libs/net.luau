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

export type receivedrequest = net.ReceivedRequest
export type serverresponse = net.ServerResponse
export type handler = net.Handler
export type configuration = net.Configuration
export type server = net.Server

function netlib.serve(config: handler | configuration): server
	return net.serve(config)
end

return table.freeze(netlib)
