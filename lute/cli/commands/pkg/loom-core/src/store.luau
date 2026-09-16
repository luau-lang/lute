local crypto = require("@lute/crypto")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")

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
	local normalizedRegistryUrl = string.gsub(registryUrl, "/+$", "")
	local digest = crypto.digest(crypto.hash.sha256, normalizedRegistryUrl)
	local hex = {}

	for index = 0, buffer.len(digest) - 1 do
		table.insert(hex, string.format("%02x", buffer.readu8(digest, index)))
	end

	return table.concat(hex)
end

local function getRegistryPackageName(name: string, registryUrl: string): string
	return `{name}--registry-{getRegistryIdentity(registryUrl)}`
end

local function getRegistryPackageKey(key: string, registryUrl: string): string
	return `{key}--registry-{getRegistryIdentity(registryUrl)}`
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
	getRegistryPackageName = getRegistryPackageName,
	getRegistryPackageKey = getRegistryPackageKey,
	ensureStoreDirectory = ensureStoreDirectory,
	toStorePath = toStorePath,
}
