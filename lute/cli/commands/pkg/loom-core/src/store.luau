local crypto = require("@lute/crypto")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local registryUrlUtil = require("./registryurl")

local STORE_PATH_PREFIX = "@pkg/"

local function getStoreDirectory(): string
	return path.format(path.join(process.homedir(), ".loom", "store"))
end

local function getPackagePath(key: string): string
	return path.format(path.join(getStoreDirectory(), key))
end

local function hasPackage(key: string): boolean
	return fs.exists(getPackagePath(key))
end

local function getRegistryIdentity(registryUrl: string): string
	local digest = crypto.digest(crypto.hash.sha256, registryUrlUtil.normalize(registryUrl))
	local hex = {}

	for index = 0, buffer.len(digest) - 1 do
		table.insert(hex, string.format("%02x", buffer.readu8(digest, index)))
	end

	return table.concat(hex)
end

local function qualifyRegistryKey(key: string, registryUrl: string): string
	local qualifier = `--registry-{getRegistryIdentity(registryUrl)}`
	if string.find(key, qualifier, 1, true) then
		return key
	end
	return `{key}{qualifier}`
end

local function ensureStoreDirectory(): ()
	local storeDir = getStoreDirectory()

	if not fs.exists(storeDir) then
		fs.createDirectory(storeDir, { makeParents = true })
	end
end

-- Returns the portable alias form stored in the lockfile, e.g. "@loom/pkg@rev".
local function toStorePath(key: string): string
	return `{STORE_PATH_PREFIX}{key}`
end

return {
	getStoreDirectory = getStoreDirectory,
	getPackagePath = getPackagePath,
	hasPackage = hasPackage,
	getRegistryIdentity = getRegistryIdentity,
	qualifyRegistryKey = qualifyRegistryKey,
	ensureStoreDirectory = ensureStoreDirectory,
	toStorePath = toStorePath,
}
