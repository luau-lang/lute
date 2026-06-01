local fs = require("@std/fs")
local github = require("./github")
local lockfile = require("./lockfile")
local path = require("@std/path")
local pp = require("@batteries/pp")
local manifest = require("./manifest")
local store = require("./store")

local function getManifestPath(directory: string): string
	return `{directory}/loom.config.luau`
end

local function getLockfilePath(directory: string): string
	return `{directory}/loom.lock.luau`
end

local function getKey(spec: manifest.DependencySpec): string
	if spec.sourceKind == "github" then
		return `{spec.name}@{spec.rev}`
	end

	return spec.name
end

local function hasConflict(resolved: lockfile.LockfileDependency, incoming: manifest.DependencySpec): boolean
	if resolved.sourceKind ~= incoming.sourceKind then
		return true
	end

	if resolved.source ~= incoming.source then
		return true
	end

	if incoming.sourceKind == "github" then
		return resolved.rev ~= incoming.rev
	end

	return false
end

local function normalizePathDependency(
	spec: manifest.DependencySpec,
	installPath: string,
	rootDirectory: string
): manifest.DependencySpec
	-- normalization is a no-op if it's not a path dependency
	if spec.sourceKind ~= "path" then
		return spec
	end

	local sourcePath = path.format(path.resolve(installPath, spec.source))
	if not fs.exists(sourcePath) then
		error(`Path dependency directory not found: {sourcePath} (for package '{spec.name}')`)
	end

	return table.freeze({
		name = spec.name,
		sourceKind = "path",
		source = path.format(path.relative(rootDirectory, sourcePath)),
	}) :: manifest.PathDependencySpec
end

local function fetchSource(spec: manifest.DependencySpec, rootDirectory: string): string
	if spec.sourceKind == "path" then
		local sourcePath = path.format(path.resolve(rootDirectory, spec.source))
		if not fs.exists(sourcePath) then
			error(`Path dependency directory not found: {sourcePath} (for package '{spec.name}')`)
		end
		return sourcePath
	elseif spec.sourceKind == "github" then
		store.ensureStoreDirectory()

		local key = getKey(spec)
		local sourcePath = store.getPackagePath(key)
		if not store.hasPackage(key) then
			github.installPackage(spec.source, spec.rev, sourcePath)
		end

		return sourcePath
	else
		error(`Unsupported source kind: {spec.sourceKind} for package {spec.name}`)
	end
end

local function resolve(rootDirectory: string): lockfile.Lockfile
	local rootManifestPath = getManifestPath(rootDirectory)
	if not fs.exists(rootManifestPath) then
		error(`Manifest file not found: {rootManifestPath}`)
	end

	local lockfilePath = getLockfilePath(rootDirectory)

	local queue: { manifest.DependencySpec } = {}

	local dependencies: { [string]: string } = {}
	local packages: { [string]: lockfile.LockfileDependency } = {}

	local rootManifest = manifest.parseFile(rootManifestPath)
	for depAlias, depSpec in rootManifest.package.dependencies do
		dependencies[depAlias] = getKey(depSpec)
		table.insert(queue, depSpec)
	end

	table.freeze(dependencies)

	local nameIndex: { [string]: string } = {}

	for _, spec in queue do
		local key = getKey(spec)

		if packages[key] then
			if hasConflict(packages[key], spec) then
				error(
					`Source mismatch for package '{spec.name}':\n`
						.. `  resolved: {packages[key].source} ({packages[key].sourceKind})\n`
						.. `  incoming: {spec.source} ({spec.sourceKind})\n`
						.. `Both resolve to '{key}' but from different sources.`
				)
			else
				-- Already resolved at this exact version — deduplicate
				continue
			end
		end

		local conflictKey = nameIndex[spec.name]
		if conflictKey then
			error(
				`Version conflict for package '{spec.name}':\n`
					.. `  resolved: {conflictKey}\n`
					.. `  incoming: {key}\n`
					.. `Resolve by pinning both to the same revision.`
			)
		end

		-- New package — resolve it
		nameIndex[spec.name] = key
		local transitiveDependencies: { [string]: string } = {}

		-- Download and install
		local installPath = fetchSource(spec, rootDirectory)

		-- Check for transitive dependencies
		local nestedManifestPath = getManifestPath(installPath)
		if fs.exists(nestedManifestPath) then
			local depManifest = manifest.parseFile(nestedManifestPath)
			for depAlias, depSpec in depManifest.package.dependencies do
				-- Normalize transitive path dep sources to be rootDirectory-relative
				local normalizedSpec = normalizePathDependency(depSpec, installPath, rootDirectory)
				transitiveDependencies[depAlias] = getKey(normalizedSpec)
				table.insert(queue, normalizedSpec)
			end
		end

		table.freeze(transitiveDependencies)

		packages[key] = table.freeze({
			name = spec.name,
			rev = if spec.sourceKind == "github" then spec.rev else nil,
			source = spec.source,
			sourceKind = spec.sourceKind,
			installPath = if spec.sourceKind == "path"
				then path.format(path.relative(rootDirectory, installPath))
				else store.toStorePath(key),
			dependencies = transitiveDependencies,
		})
	end

	table.freeze(packages)

	local lock: lockfile.Lockfile = table.freeze({
		version = 3,
		packages = packages,
		dependencies = dependencies,
	})

	fs.writeStringToFile(lockfilePath, `return {pp(lock)}\n`)

	return lock
end

return {
	resolve = resolve,
}
