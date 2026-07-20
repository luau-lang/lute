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

local function resolveProviderPathsFromConfig(directory: string): { string }?
	local configPath = path.format(path.join(directory, ".config.luau"))
	if not fs.exists(configPath) then
		return nil
	end

	local ok, config = pcall(luau.loadModule, configPath, nil)
	if not ok or typeof(config) ~= "table" then
		error(`Failed to load config {configPath}: {config}`)
	end

	if config.lute == nil then
		return nil
	elseif typeof(config.lute) ~= "table" then
		error(`Config {configPath}: lute must be a table`)
	end

	local credentials = config.lute.credentials
	if credentials == nil then
		return nil
	elseif typeof(credentials) ~= "table" then
		error(`Config {configPath}: lute.credentials must be a table`)
	end

	local providers = credentials.providers
	if providers == nil then
		return nil
	elseif typeof(providers) ~= "table" then
		error(`Config {configPath}: lute.credentials.providers must be an array of strings`)
	end

	local resolvedPaths: { string } = {}
	for _, providerPath in providers do
		if typeof(providerPath) ~= "string" then
			error(`Credential provider path in config {configPath} must be a string`)
		end
		local resolvedPath = if path.isAbsolute(providerPath)
			then providerPath
			else path.format(path.resolve(path.dirname(configPath), providerPath))
		if not fs.exists(resolvedPath) then
			error(`Credential provider path {resolvedPath} for config {configPath} does not exist`)
		else
			table.insert(resolvedPaths, resolvedPath)
		end
	end
	return table.freeze(resolvedPaths)
end

local function findCredentialProviderPaths(): { string }?
	local directory = path.format(process.cwd())
	while true do
		local providerPaths = resolveProviderPathsFromConfig(directory)
		if providerPaths ~= nil then
			return providerPaths
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

	local providerPaths = findCredentialProviderPaths()
	if providerPaths == nil then
		cachedProviders = EMPTY_PROVIDERS
		return EMPTY_PROVIDERS
	end

	local providers: CredentialProviders = {}

	for _, providerPath in providerPaths do
		local provider = loadProvider(providerPath)
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
