local fs = require("@std/fs")
local github = require("./github")
local lockfile = require("./lockfile")
local path = require("@std/path")
local pp = require("@batteries/pp")
local manifest = require("./manifest")
local semver = require("./semver")
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

local function resolve(rootDirectory: string, universe: semver.Universe?): lockfile.Lockfile
	local rootManifestPath = getManifestPath(rootDirectory)
	if not fs.exists(rootManifestPath) then
		error(`Manifest file not found: {rootManifestPath}`)
	end

	local lockfilePath = getLockfilePath(rootDirectory)

	local queue: { manifest.DependencySpec } = {}

	local dependencies: { [string]: string } = {}
	local packages: { [string]: lockfile.LockfileDependency } = {}

	local rootManifest = manifest.parseFile(rootManifestPath)
	local registryRoots: { [string]: semver.Requirement } = {}
	local transitiveRegistryRequirements: { [string]: semver.Requirement } = {}
	local transitiveRegistryDeps: { [string]: { [string]: string } } = {}

	for depAlias, depSpec in rootManifest.package.dependencies do
		if depSpec.sourceKind == "registry" then
			registryRoots[depAlias] = {
				name = depSpec.name,
				constraint = semver.parseConstraint(depSpec.version),
				requiredBy = depAlias,
			}
			continue
		end

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

				if normalizedSpec.sourceKind == "registry" then
					transitiveRegistryRequirements[`{key}:{depAlias}`] = {
						name = normalizedSpec.name,
						constraint = semver.parseConstraint(normalizedSpec.version),
						requiredBy = key,
					}
					if not transitiveRegistryDeps[key] then
						transitiveRegistryDeps[key] = {}
					end
					transitiveRegistryDeps[key][depAlias] = normalizedSpec.name
					continue
				end

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

	-- Phase 2: resolve registry deps via the semver solver
	if next(registryRoots) ~= nil or next(transitiveRegistryRequirements) ~= nil then
		assert(universe ~= nil, "Registry dependencies require a universe to be provided")

		local solverInputs = table.clone(registryRoots)
		for k, v in transitiveRegistryRequirements do
			solverInputs[k] = v
		end

		local resolution = semver.solve(universe, solverInputs)

		for name, pkgVersion in resolution do
			local key = `{name}@{pkgVersion.versionString}`

			local transitiveDependencies: { [string]: string } = {}
			for alias, dep in pkgVersion.dependencies do
				local depPkgVersion = resolution[dep.name]
				assert(depPkgVersion ~= nil, `Solver produced an incomplete resolution: missing '{dep.name}'`)
				transitiveDependencies[alias] = `{dep.name}@{depPkgVersion.versionString}`
			end
			table.freeze(transitiveDependencies)

			packages[key] = table.freeze({
				name = name,
				rev = pkgVersion.versionString,
				source = name,
				sourceKind = "registry",
				installPath = store.toStorePath(key),
				dependencies = transitiveDependencies,
			} :: lockfile.LockfileDependency)
		end

		-- Back-fill transitive registry dep keys into phase-1 package entries now that versions are known.
		for pkgKey, pendingDeps in transitiveRegistryDeps do
			local entry = packages[pkgKey]
			local updatedDeps = table.clone(entry.dependencies)

			for depAlias, registryName in pendingDeps do
				local pkgVersion = resolution[registryName]
				assert(pkgVersion ~= nil, `Solver did not resolve transitive registry dep '{registryName}'`)
				updatedDeps[depAlias] = `{registryName}@{pkgVersion.versionString}`
			end

			packages[pkgKey] = table.freeze({
				name = entry.name,
				rev = entry.rev,
				source = entry.source,
				sourceKind = entry.sourceKind,
				installPath = entry.installPath,
				dependencies = table.freeze(updatedDeps),
			} :: lockfile.LockfileDependency)
		end

		-- Write root-level registry dependency aliases now that versions are resolved
		local mutableDependencies = table.clone(dependencies)
		for alias, req in registryRoots do
			local pkgVersion = resolution[req.name]
			assert(pkgVersion ~= nil, `Solver did not resolve root dependency '{req.name}'`)
			mutableDependencies[alias] = `{req.name}@{pkgVersion.versionString}`
		end
		dependencies = table.freeze(mutableDependencies)
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
