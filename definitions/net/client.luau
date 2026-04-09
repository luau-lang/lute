-- lute-lint-global-ignore(unused_variable)
local client = {}

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

function client.request(url: string, metadata: Metadata?): Response
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
	send: (self: WebSocket, data: string, binary: boolean?) -> (),
	close: (self: WebSocket) -> (),
}

function client.websocket(url: string, options: WebSocketOptions?): WebSocket
	error("not implemented")
end

return client
