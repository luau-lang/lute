local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")
local pp = require("@batteries/pp")

export type AuthenticationEntry = {
	read token: string,
}

export type AuthenticationStore = {
	[string]: AuthenticationEntry,
}

local function getAuthenticationFilePath(): string
	local homedir = path.join(process.homedir(), ".loom", "auth.luau")
	return path.format(homedir)
end

local function parseStore(s: unknown): AuthenticationStore
	assert(s ~= nil and type(s) == "table", "Expected store to be a table")
	for domain, entry in s do
		assert(type(domain) == "string", "Expected domain to be a string")
		assert(type(entry) == "table", "Expected entry to be a table")
		assert(type(entry.token) == "string", "Expected token to be a string")
		table.freeze(entry)
	end
	table.freeze(s)
	return s
end

local function loadAuthenticationStore(): AuthenticationStore
	local authPath = getAuthenticationFilePath()
	local ok, result = pcall(luau.loadModule, authPath, nil)
	if not ok or type(result) ~= "table" then
		local store: AuthenticationStore = {}
		return table.freeze(store)
	end
	return parseStore(result)
end

local function saveAuthenticationStore(store: AuthenticationStore)
	local authPath = getAuthenticationFilePath()
	local authDir = path.format(path.parse(path.dirname(authPath)))
	fs.createDirectory(authDir, { makeParents = true })
	fs.writeStringToFile(authPath, `return {pp(store)}\n`)
end

local function updateAuthenticationStore(store: AuthenticationStore, domain: string, token: string): AuthenticationStore
	local newStore = table.clone(store)
	newStore[domain] = table.freeze({ token = token })
	table.freeze(newStore)
	return newStore
end

local function saveAuthenticationToken(domain: string, token: string)
	local store = loadAuthenticationStore()
	local newStore = updateAuthenticationStore(store, domain, token)
	saveAuthenticationStore(newStore)
	print(`Credentials saved for {domain}`)
end

return {
	loadAuthenticationStore = loadAuthenticationStore,
	saveAuthenticationToken = saveAuthenticationToken,
}
