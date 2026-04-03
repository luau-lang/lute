local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")

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

	local ok, content = pcall(fs.readFileToString, authPath)
	if not ok then
		return {}
	end

	local compileOk, bytecode = pcall(luau.compile, content)
	if not compileOk then
		return {}
	end

	local loadOk, func = pcall(luau.load, bytecode, authPath, nil)
	if not loadOk then
		return {}
	end

	local execOk, result = pcall(func)
	if not execOk or type(result) ~= "table" then
		return {}
	end

	return result
end

return {
	loadAuthenticationStore = loadAuthenticationStore,
}
