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
	ensureStoreDirectory = ensureStoreDirectory,
	toStorePath = toStorePath,
}
