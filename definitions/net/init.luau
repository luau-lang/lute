-- lute-lint-global-ignore(unused_variable)
local client = require("@self/client")
local server = require("@self/server")

local net = {}

export type Metadata = client.Metadata
export type Response = client.Response
export type ReceivedRequest = server.ReceivedRequest
export type ServerResponse = server.ServerResponse
export type Handler = server.Handler
export type Configuration = server.Configuration
export type Server = server.Server

net.client = client
net.server = server

return net
