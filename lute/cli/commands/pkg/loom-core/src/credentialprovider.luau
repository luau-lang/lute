local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")

export type CredentialRequest = {
	read protocol: string,
	read host: string,
	read path: string?,
}

export type CredentialProvider = (request: CredentialRequest) -> string?

export type CredentialProviders = { [string]: CredentialProvider }

local function loadProviders(): CredentialProviders
	local configPath = path.join(process.homedir(), ".lute", "config.luau")
	if not fs.exists(configPath) then
		return {}
	end

	local config = luau.loadModule(path.format(configPath))
	if typeof(config) ~= "table" then
		error(`Expected {path.format(configPath)} to return a table`)
	end

	local credentials = config.credentials
	if credentials == nil then
		return {}
	end
	if typeof(credentials) ~= "table" then
		error(`Expected 'credentials' in {path.format(configPath)} to be a table`)
	end

	local providers: CredentialProviders = {}
	for host, provider in credentials do
		if typeof(host) ~= "string" or typeof(provider) ~= "function" then
			error("Credential entries must map host strings to functions")
		end
		providers[host] = provider
	end

	return table.freeze(providers)
end

local function resolveToken(request: CredentialRequest): string?
	local providers = loadProviders()
	local provider = providers[request.host]
	if provider == nil or typeof(provider) ~= "function" then
		return nil
	end

	local frozenRequest = table.freeze({
		protocol = request.protocol,
		host = request.host,
		path = request.path,
	})

	local ok, token = pcall(provider, frozenRequest)
	if not ok then
		error(`Credential provider for {request.host} failed: {token}`)
	end
	if token == nil or token == "" then
		return nil
	end
	if typeof(token) ~= "string" then
		error(`Credential provider for {request.host} must return a string or nil`)
	end
	if token:match("[\0-\31]") then
		error(`Credential provider for {request.host} returned a token containing control characters`)
	end

	return token
end

return {
	resolveToken = resolveToken,
}
