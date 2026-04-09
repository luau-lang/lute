local client = require("@self/client")
local server = require("@self/server")

local net = {}

export type Metadata = client.Metadata
export type Response = client.Response
export type WebSocketOptions = client.WebSocketOptions
export type WebSocket = client.WebSocket
export type ReceivedRequest = server.ReceivedRequest
export type ServerResponse = server.ServerResponse
export type Handler = server.Handler
export type Configuration = server.Configuration
export type Server = server.Server
export type ServerWebSocket = server.ServerWebSocket
export type WebSocketHandlers = server.WebSocketHandlers

net.client = client
net.server = server

return net
