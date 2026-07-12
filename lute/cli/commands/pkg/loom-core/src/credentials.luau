local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")

export type CredentialRequest = {
	read protocol: string,
	read host: string,
	read path: string?,
}

export type CredentialResolver = (request: CredentialRequest) -> string?

export type CredentialResolvers = { [string]: CredentialResolver }

local cachedResolvers: CredentialResolvers? = nil

local function loadResolvers(): CredentialResolvers
	if cachedResolvers ~= nil then
		return cachedResolvers
	end

	local resolvers: CredentialResolvers = {}

	local configPath = path.join(process.homedir(), ".lute", "config.luau")
	if not fs.exists(configPath) then
		cachedResolvers = table.freeze(resolvers)
		return resolvers
	end

	local ok, config = pcall(luau.loadModule, configPath, nil)
	if not ok then
		error(`Failed to load credential resolvers from {path.format(configPath)}: {config}`)
	end
	if typeof(config) ~= "table" then
		error(`Expected {path.format(configPath)} to return a table`)
	end

	local configuredResolvers = config.credentialResolvers
	if configuredResolvers ~= nil then
		if typeof(configuredResolvers) ~= "table" then
			error(`Expected 'credentialResolvers' in {path.format(configPath)} to be a table`)
		end

		for host, resolver in configuredResolvers do
			if typeof(host) ~= "string" or typeof(resolver) ~= "function" then
				error("Credential resolver entries must map host strings to functions")
			end
			resolvers[host] = resolver
		end
	end

	cachedResolvers = table.freeze(resolvers)
	return resolvers
end

local function resolve(request: CredentialRequest): string?
	local resolvers = loadResolvers()
	local resolver = resolvers[request.host] or resolvers["*"]
	if resolver == nil or typeof(resolver) ~= "function" then
		return nil
	end

	local frozenRequest = table.freeze({
		protocol = request.protocol,
		host = request.host,
		path = request.path,
	})

	local ok, token = pcall(resolver, frozenRequest)
	if not ok then
		error(`Credential resolver for {request.host} failed: {token}`)
	end
	if token == nil or token == "" then
		return nil
	end
	if typeof(token) ~= "string" then
		error(`Credential resolver for {request.host} must return a string or nil`)
	end
	if token:match("[\0-\31]") then
		error(`Credential resolver for {request.host} returned a token containing control characters`)
	end

	return token
end

return {
	resolve = resolve,
}
