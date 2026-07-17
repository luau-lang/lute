local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")
local stringext = require("@std/stringext")

export type CredentialRequest = {
	read protocol: string,
	read host: string,
	read path: string?,
}

export type CredentialProvider = {
	read host: string,
	read resolve: (request: CredentialRequest) -> string?,
}

export type CredentialProviders = { [string]: CredentialProvider }

local cachedProviders: CredentialProviders? = nil

local EMPTY_PROVIDERS = table.freeze({} :: CredentialProviders)

local function parseProvider(provider: any): CredentialProvider?
	if typeof(provider) ~= "table" then
		return nil
	end
	if typeof(provider.host) ~= "string" then
		return nil
	end
	if typeof(provider.resolve) ~= "function" then
		return nil
	end
	return provider
end

local function loadProvider(path: string): CredentialProvider?
	local ok, provider = pcall(luau.loadModule, path, nil)
	return if ok then parseProvider(provider) else nil
end

local function loadProviderFromConfig(directory: string): string?
	local configPath = path.format(path.join(directory, ".config.luau"))
	if fs.exists(configPath) then
		local ok, config = pcall(luau.loadModule, configPath, nil)
		if
			ok
			and typeof(config) == "table"
			and typeof(config.lute) == "table"
			and typeof(config.lute.credentials) == "table"
			and typeof(config.lute.credentials.providers) == "string"
		then
			local resolvedPath = path.format(path.resolve(path.dirname(configPath), config.lute.credentials.providers))
			if not fs.exists(resolvedPath) then
				print(`Credential providers path {resolvedPath} for config {configPath} does not exist`)
			else
				return resolvedPath
			end
		end
	end
	return nil
end

local function findCredentialProvidersPath(): string?
	local directory = path.format(process.cwd())
	while true do
		local providersPath = loadProviderFromConfig(directory)
		if providersPath ~= nil then
			return providersPath
		end
		local parent = path.format(path.dirname(directory))
		if parent == directory then
			return nil
		end
		directory = parent
	end
end

local function loadProviders(): CredentialProviders
	if cachedProviders ~= nil then
		return cachedProviders
	end

	local providersPath = findCredentialProvidersPath()
	if providersPath == nil then
		cachedProviders = EMPTY_PROVIDERS
		return EMPTY_PROVIDERS
	end

	if not fs.exists(providersPath) then
		cachedProviders = EMPTY_PROVIDERS
		return EMPTY_PROVIDERS
	end

	local providers: CredentialProviders = {}

	for _, entry in fs.listDirectory(providersPath) do
		local entryPath = path.format(path.join(providersPath, entry.name))
		local provider = loadProvider(entryPath)
		if provider ~= nil then
			if providers[provider.host] ~= nil then
				error(`Duplicate credential provider for host: {provider.host}`)
			end
			providers[provider.host] = provider
		end
	end

	cachedProviders = table.freeze(providers)
	return providers
end

local function resolveToken(request: CredentialRequest): string?
	local providers = loadProviders()
	local provider = providers[request.host]
	if provider == nil then
		return nil
	end
	local ok, token = pcall(provider.resolve, request)
	if not ok then
		error(`Credential provider for {request.host} failed: {token}`)
	end
	if token == nil then
		return nil
	end
	if typeof(token) ~= "string" then
		error(`Credential provider for {request.host} must return a string or nil`)
	end
	token = stringext.trim(token)
	if token == "" then
		return nil
	end
	if token:match("[\0-\31]") then
		error(`Credential provider for {request.host} returned a token containing control characters`)
	end
	return token
end

return {
	resolveToken = resolveToken,
}
