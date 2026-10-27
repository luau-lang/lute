local crypto = require("@lute/crypto")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local registryUrl = require("./registryurl")

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

local function sha256Hex(value: string): string
	local digest = crypto.digest(crypto.hash.sha256, value)
	local hex = {}

	for index = 0, buffer.len(digest) - 1 do
		table.insert(hex, string.format("%02x", buffer.readu8(digest, index)))
	end

	return table.concat(hex)
end

local function getRegistryIdentity(registryUrlValue: string): string
	return sha256Hex(registryUrl.normalize(registryUrlValue))
end

local function getGitHubCheckoutKey(source: string, rev: string): string
	local normalizedSource = string.gsub(source, "/+$", "")
	local repositoryName = string.match(normalizedSource, "([^/]+)$") or "repository"
	repositoryName = string.gsub(repositoryName, "%.git$", "")
	repositoryName = string.gsub(repositoryName, "[^%w%-_.]", "-")

	return `{repositoryName}--github-{sha256Hex(normalizedSource)}@{sha256Hex(rev)}`
end

local function qualifyRegistryKey(key: string, registryUrlValue: string): string
	local qualifier = `--registry-{getRegistryIdentity(registryUrlValue)}`
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

local function getGitHubInstallPath(source: string, rev: string, target: string?): string
	local checkoutPath = toStorePath(getGitHubCheckoutKey(source, rev))
	if target then
		local installPath = path.join(checkoutPath, target)
		return path.posix.format({
			parts = installPath.parts,
			absolute = false,
		})
	end
	return checkoutPath
end

return {
	getStoreDirectory = getStoreDirectory,
	getPackagePath = getPackagePath,
	hasPackage = hasPackage,
	getRegistryIdentity = getRegistryIdentity,
	getGitHubCheckoutKey = getGitHubCheckoutKey,
	getGitHubInstallPath = getGitHubInstallPath,
	qualifyRegistryKey = qualifyRegistryKey,
	ensureStoreDirectory = ensureStoreDirectory,
	toStorePath = toStorePath,
}
