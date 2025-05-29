local net = {}

export type metadata = {
	method: string?,
	body: string?,
	headers: { [string]: string }?,
}

export type request = {
	body: string,
	headers: { [string]: string },
	status: number,
	ok: boolean,
}

function net.request(url: string, metadata: metadata?): request
	error("not implemented")
end

export type handler = (...any) -> ...any

export type configuration = {
	hostname: string?,
	port: number?,
	reuseport: boolean?,
	tls: { cert_file_name: string, key_file_name: string, passphrase: string?, ca_file_name: string? },
	handler: handler,
}

function net.serve(config: configuration | handler)
	error("not implemented")
end

return net
