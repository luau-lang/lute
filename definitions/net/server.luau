-- lute-lint-global-ignore(unused_variable)
local server = {}

--- An HTTP request received by the server, containing method, path, body, query params, and headers.
export type ReceivedRequest = {
	method: string,
	path: string,
	body: string,
	query: { [string]: string },
	headers: { [string]: string },
}

--- A response that can be returned from a server handler: a plain string body, or a table with status, body, and headers.
export type ServerResponse = string | {
	status: number?,
	body: string?,
	headers: { [string]: string }?,
}

--- A server-side WebSocket connection handle.
export type ServerWebSocket = {
	send: (self: ServerWebSocket, data: string | buffer) -> number,
	close: (self: ServerWebSocket, code: number?, message: string?) -> (),
}

--- Event handlers for server-side WebSocket connections.
export type WebSocketHandlers = {
	open: ((ws: ServerWebSocket) -> ())?,
	message: ((ws: ServerWebSocket, message: string | buffer) -> ())?,
	close: ((ws: ServerWebSocket, code: number, message: string) -> ())?,
	drain: ((ws: ServerWebSocket) -> ())?,
}

--- A running HTTP server handle, with hostname, port, and lifecycle methods.
export type Server = {
	hostname: string,
	port: number,
	close: () -> (),
	upgrade: (self: Server, req: ReceivedRequest) -> boolean,
}

--- A request handler function: receives a `ReceivedRequest` and `Server`, and returns a `ServerResponse`.
export type Handler = (request: ReceivedRequest, server: Server) -> ServerResponse?

--- Configuration for starting an HTTP server.
export type Configuration = {
	hostname: string?,
	port: number?,
	reuseport: boolean?,
	tls: { certfilename: string, keyfilename: string, passphrase: string?, cafilename: string? }?,
	handler: Handler?,
	websocket: WebSocketHandlers?,
}

--- Starts an HTTP server with the given handler or full configuration. Returns a `Server` handle.
function server.serve(config: Handler | Configuration): Server
	error("not implemented")
end

return server
