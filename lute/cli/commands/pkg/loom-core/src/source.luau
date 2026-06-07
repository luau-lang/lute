local fs = require("@std/fs")
local github = require("./github")
local manifest = require("./manifest")
local path = require("@std/path")
local store = require("./store")

local function getKey(spec: manifest.DependencySpec): string
	if spec.sourceKind == "github" then
		return `{spec.name}@{spec.rev}`
	end
	return spec.name
end

local function fetch(spec: manifest.DependencySpec, rootDirectory: string): string
	if spec.sourceKind == "path" then
		local abs = path.format(path.resolve(rootDirectory, spec.source))
		if not fs.exists(abs) then
			error(`Path dependency directory not found: {abs} (for package '{spec.name}')`)
		end
		return abs
	elseif spec.sourceKind == "github" then
		store.ensureStoreDirectory()
		local key = getKey(spec)
		local abs = store.getPackagePath(key)
		if not store.hasPackage(key) then
			github.installPackage(spec.source, spec.rev, abs)
		end
		return abs
	end
	error(`Unknown source kind`)
end

return {
	getKey = getKey,
	fetch = fetch,
}
