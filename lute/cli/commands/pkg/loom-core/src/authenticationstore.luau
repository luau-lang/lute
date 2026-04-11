local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")
local pp = require("@batteries/pp")

export type AuthenticationEntry = {
	token: string,
}

export type AuthenticationStore = {
	[string]: AuthenticationEntry,
}

local function getAuthenticationFilePath(): string
	local homedir = path.join(process.homedir(), ".loom", "auth.luau")
	return path.format(homedir)
end

local function loadAuthenticationStore(): AuthenticationStore
	local authPath = getAuthenticationFilePath()
	local ok, result = pcall(luau.loadModule, authPath, nil)
	if not ok or type(result) ~= "table" then
		return {}
	end
	return result
end

local function saveAuthenticationStore(store: AuthenticationStore)
	local authPath = getAuthenticationFilePath()
	local authDir = path.format(path.parse(path.dirname(authPath)))
	fs.createDirectory(authDir, { makeParents = true })
	fs.writeStringToFile(authPath, `return {pp(store)}\n`)
end

local function saveAuthenticationToken(domain: string, token: string)
	local store = loadAuthenticationStore()
	store[domain] = { token = token }
	saveAuthenticationStore(store)
	print(`Credentials saved for {domain}`)
end

return {
	loadAuthenticationStore = loadAuthenticationStore,
	saveAuthenticationToken = saveAuthenticationToken,
}
