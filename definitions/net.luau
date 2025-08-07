local net = {}

export type Metadata = {
	method: string?,
	body: string?,
	headers: { [string]: string }?,
}

export type Request = {
	body: string,
	headers: { [string]: string },
	status: number,
	ok: boolean,
}

function net.request(url: string, metadata: Metadata?): Request
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

function net.serve(config: Handler | Configuration)
	error("not implemented")
end

return net
