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
	local nameIndex: { [string]: string } = {}

	-- All registry solver inputs: root-level dependencies keyed by alias, transitive by "{pkgKey}:{dependencyAlias}".
	local registryRequirements: { [string]: semver.Requirement } = {}
	local registrySources: { [string]: string } = {}

	-- stores a solved source for a particular name, erroring if there's a conflict
	local function registerSource(name: string, source: string)
		local existing = registrySources[name]
		if existing and existing ~= source then
			error(
				`Source conflict for package '{name}':\n`
					.. `  '{existing}' vs '{source}'\n`
					.. `Both reference the same package name with different sources.`
			)
		end

		registrySources[name] = source
	end

	-- Root aliases that need a resolved key written back into `dependencies` after solving.
	local rootRegistryAliases: { string } = {}
	-- Per-package registry aliases that need keys written into their dependency table after solving.
	local unresolvedRegistryDependencies: { [string]: { [string]: string } } = {}
	-- Open (not yet finalized) dependency maps for unversioned packages; registry entries are filled in during versioned resolution.
	local openDependencies: { [string]: { [string]: string } } = {}

	local rootManifest = manifest.parseFile(rootManifestPath)

	for dependencyAlias, dependencySpec in rootManifest.package.dependencies do
		if dependencySpec.sourceKind == "registry" then
			registryRequirements[dependencyAlias] = {
				name = dependencySpec.name,
				constraint = semver.parseConstraint(dependencySpec.version),
				requiredBy = dependencyAlias,
			}

			registerSource(dependencySpec.name, dependencySpec.source)
			table.insert(rootRegistryAliases, dependencyAlias)
			continue
		end

		dependencies[dependencyAlias] = getKey(dependencySpec)
		table.insert(queue, dependencySpec)
	end

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

		nameIndex[spec.name] = key
		local transitiveDependencies: { [string]: string } = {}
		openDependencies[key] = transitiveDependencies

		local installPath = fetchSource(spec, rootDirectory)

		local nestedManifestPath = getManifestPath(installPath)
		if fs.exists(nestedManifestPath) then
			local dependencyManifest = manifest.parseFile(nestedManifestPath)
			for dependencyAlias, dependencySpec in dependencyManifest.package.dependencies do
				local normalizedSpec = normalizePathDependency(dependencySpec, installPath, rootDirectory)

				if normalizedSpec.sourceKind == "registry" then
					registryRequirements[`{key}:{dependencyAlias}`] = {
						name = normalizedSpec.name,
						constraint = semver.parseConstraint(normalizedSpec.version),
						requiredBy = key,
					}

					registerSource(normalizedSpec.name, normalizedSpec.source)

					if not unresolvedRegistryDependencies[key] then
						unresolvedRegistryDependencies[key] = {}
					end

					unresolvedRegistryDependencies[key][dependencyAlias] = normalizedSpec.name
					continue
				end

				transitiveDependencies[dependencyAlias] = getKey(normalizedSpec)
				table.insert(queue, normalizedSpec)
			end
		end

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

	-- Versioned dependency resolution: solve registry dependencies and stitch them into the package graph.
	if next(registryRequirements) ~= nil then
		assert(universe ~= nil, "Registry dependencies require a universe to be provided")

		local resolution = semver.solve(universe, registryRequirements)

		for name, pkgVersion in resolution do
			local key = `{name}@{pkgVersion.versionString}`

			local transitiveDependencies: { [string]: string } = {}
			for alias, dependency in pkgVersion.dependencies do
				local resolvedVersion = resolution[dependency.name]
				assert(resolvedVersion ~= nil, `Solver produced an incomplete resolution: missing '{dependency.name}'`)

				transitiveDependencies[alias] = `{dependency.name}@{resolvedVersion.versionString}`
			end

			packages[key] = table.freeze({
				name = name,
				rev = pkgVersion.versionString,
				source = registrySources[name] or name,
				sourceKind = "registry",
				installPath = store.toStorePath(key),
				dependencies = table.freeze(transitiveDependencies),
			} :: lockfile.LockfileDependency)
		end

		-- Fill in pending registry dependency keys directly into the unversioned packages' dependency tables.
		for pkgKey, unresolvedAliases in unresolvedRegistryDependencies do
			local packageDependencies = openDependencies[pkgKey]
			for dependencyAlias, registryName in unresolvedAliases do
				local pkgVersion = resolution[registryName]
				assert(pkgVersion ~= nil, `Solver did not resolve transitive registry dependency '{registryName}'`)
				packageDependencies[dependencyAlias] = `{registryName}@{pkgVersion.versionString}`
			end
		end

		-- Write root-level registry dependency aliases now that versions are resolved.
		for _, alias in rootRegistryAliases do
			local req = registryRequirements[alias]
			local pkgVersion = resolution[req.name]
			assert(pkgVersion ~= nil, `Solver did not resolve root dependency '{req.name}'`)
			dependencies[alias] = `{req.name}@{pkgVersion.versionString}`
		end
	end

	for _, packageDependencies in openDependencies do
		table.freeze(packageDependencies)
	end

	table.freeze(packages)
	table.freeze(dependencies)

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
