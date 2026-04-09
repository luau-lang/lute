-- lute-lint-global-ignore(unused_variable)
local server = {}

export type ReceivedRequest = {
	method: string,
	path: string,
	body: string,
	query: { [string]: string },
	headers: { [string]: string },
}

export type ServerResponse = string | {
	status: number?,
	body: string?,
	headers: { [string]: string }?,
}

export type ServerWebSocket = {
	send: (self: ServerWebSocket, data: string, binary: boolean?) -> boolean,
	close: (self: ServerWebSocket, code: number?, message: string?) -> (),
}

export type WebSocketHandlers = {
	open: ((ws: ServerWebSocket) -> ())?,
	message: ((ws: ServerWebSocket, message: string, binary: boolean) -> ())?,
	close: ((ws: ServerWebSocket, code: number, message: string) -> ())?,
	drain: ((ws: ServerWebSocket) -> ())?,
}

export type Server = {
	hostname: string,
	port: number,
	close: () -> (),
	upgrade: (self: Server, req: ReceivedRequest) -> boolean,
}

export type Handler = (request: ReceivedRequest, server: Server) -> ServerResponse?

export type Configuration = {
	hostname: string?,
	port: number?,
	reuseport: boolean?,
	tls: { certfilename: string, keyfilename: string, passphrase: string?, cafilename: string? }?,
	handler: Handler?,
	websocket: WebSocketHandlers?,
}

function server.serve(config: Handler | Configuration): Server
	error("not implemented")
end

return server
