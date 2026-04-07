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

return client
