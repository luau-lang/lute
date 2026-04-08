-- lute-lint-global-ignore(unused_variable)
local net = {}
local client = {}
local server = {}

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

export type Handler = (request: ReceivedRequest) -> ServerResponse

export type Configuration = {
	hostname: string?,
	port: number?,
	reuseport: boolean?,
	tls: { certfilename: string, keyfilename: string, passphrase: string?, cafilename: string? }?,
	handler: Handler,
}

export type Server = {
	hostname: string,
	port: number,
	close: () -> (),
}

function server.serve(config: Handler | Configuration): Server
	error("not implemented")
end

net.client = client
net.server = server

return net
