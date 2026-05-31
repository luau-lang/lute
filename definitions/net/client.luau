-- lute-lint-global-ignore(unused_variable)
local time = require("../time")

local client = {}

--- HTTP request metadata, including optional method, body, and headers.
export type Metadata = {
	method: string?,
	body: string?,
	headers: { [string]: string }?,
}

--- An HTTP response, containing status code, headers, body, and a success flag.
export type Response = {
	body: string,
	headers: { [string]: string },
	status: number,
	ok: boolean,
}

--- Makes an HTTP request to `url` with optional request metadata. Returns the response.
function client.request(url: string, metadata: Metadata?): Response
	error("not implemented")
end

--- Options for establishing a WebSocket connection, including optional event handlers.
export type WebSocketOptions = {
	headers: { [string]: string }?,
	onopen: (() -> ())?,
	onmessage: ((message: string | buffer) -> ())?,
	onclose: ((code: number, reason: string) -> ())?,
	onerror: ((error: string) -> ())?,
}

--- A client-side WebSocket connection handle.
export type WebSocket = {
	send: (self: WebSocket, data: string | buffer) -> (),
	close: (self: WebSocket) -> (),
}

--- Opens a WebSocket connection to `url`. Returns a `WebSocket` handle.
function client.websocket(url: string, options: WebSocketOptions?): WebSocket
	error("not implemented")
end

export type TCPStreamHandle = {
	write: (self: TCPStreamHandle, data: buffer | string) -> (),
	read: ((self: TCPStreamHandle, amount: number?, timeout: time.Duration?) -> buffer)
		& ((self: TCPStreamHandle, timeout: time.Duration) -> buffer),
	close: (self: TCPStreamHandle) -> (),
}

function client.connect(host: string, port: number): TCPStreamHandle
	error("not implemented")
end

return client
