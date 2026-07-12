local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")

export type AuthenticationRequest = {
	read protocol: string,
	read host: string,
	read path: string?,
}

export type AuthenticationProvider = (request: AuthenticationRequest) -> string?

export type AuthenticationProviders = { [string]: AuthenticationProvider }

local cachedProviders: AuthenticationProviders? = nil

local function loadProviders(): AuthenticationProviders
	if cachedProviders ~= nil then
		return cachedProviders
	end

	local providers: AuthenticationProviders = {}

	local configPath = path.join(process.homedir(), ".lute", "config.luau")
	if not fs.exists(configPath) then
		cachedProviders = table.freeze(providers)
		return providers
	end

	local ok, config = pcall(luau.loadModule, configPath, nil)
	if not ok then
		error(`Failed to load auth providers from {path.format(configPath)}: {config}`)
	end
	if typeof(config) ~= "table" then
		error(`Expected {path.format(configPath)} to return a table`)
	end

	local configuredProviders = config.auth
	if configuredProviders ~= nil then
		if typeof(configuredProviders) ~= "table" then
			error(`Expected 'auth' in {path.format(configPath)} to be a table`)
		end

		for host, provider in configuredProviders do
			if typeof(host) ~= "string" or typeof(provider) ~= "function" then
				error("Auth provider entries must map host strings to functions")
			end
			providers[host] = provider
		end
	end

	cachedProviders = table.freeze(providers)
	return providers
end

local function resolveToken(request: AuthenticationRequest): string?
	local providers = loadProviders()
	local provider = providers[request.host] or providers["*"]
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
		error(`Auth provider for {request.host} failed: {token}`)
	end
	if token == nil or token == "" then
		return nil
	end
	if typeof(token) ~= "string" then
		error(`Auth provider for {request.host} must return a string or nil`)
	end
	if token:match("[\0-\31]") then
		error(`Auth provider for {request.host} returned a token containing control characters`)
	end

	return token
end

return {
	resolveToken = resolveToken,
}
