local net = {}

export type Metadata = {
	method: string?,
	body: string?,
	headers: { [string]: string }?,
}

export type Response = {
	body: string,
	headers: { [string]: string },
	status: number,
	ok: boolean,
}

function net.request(url: string, metadata: Metadata?): Response
	error("not implemented")
end

export type WebSocketOptions = {
	headers: { [string]: string }?,
	protocol: string?,
	onopen: (() -> ())?,
	onmessage: ((message: string, binary: boolean) -> ())?,
	onclose: ((code: number, reason: string) -> ())?,
	onerror: ((error: string) -> ())?,
}

export type WebSocket = {
	send: (self: WebSocket, data: string, binary: boolean?) -> boolean,
	close: (self: WebSocket) -> (),
}

function net.websocket(url: string, options: WebSocketOptions?): WebSocket
	error("not implemented")
end

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

export type Handler = (request: ReceivedRequest, server: Server) -> ServerResponse?

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

export type Configuration = {
	hostname: string?,
	port: number?,
	reuseport: boolean?,
	tls: { certfilename: string, keyfilename: string, passphrase: string?, cafilename: string? }?,
	handler: Handler?,
	websocket: WebSocketHandlers?,
}

export type Server = {
	hostname: string,
	port: number,
	close: () -> (),
	upgrade: (self: Server, req: ReceivedRequest) -> boolean,
}

function net.serve(config: Handler | Configuration): Server
	error("not implemented")
end

return net
