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

export type ResolveOptions = {
	read excludeDev: boolean?,
	read locked: boolean?,
}

local function removeRequirementsForPackage(registryRequirements: { [string]: semver.Requirement }, packageName: string)
	for reqKey, req in registryRequirements do
		if req.name == packageName then
			registryRequirements[reqKey] = nil
		end
	end
end

local function buildEffectiveUniverse(
	universe: semver.Universe,
	overrides: { [string]: manifest.DependencySpec }
): (semver.Universe, { [string]: { [string]: string } })
	local registryOverrides: { [string]: semver.Constraint } = {}
	local sourceOverrideNames: { [string]: boolean } = {}
	for name, spec in overrides do
		if spec.sourceKind == "registry" then
			registryOverrides[name] = semver.parseConstraint(spec.version)
		else
			sourceOverrideNames[name] = true
		end
	end

	local effective: semver.Universe = {}
	local sourceOverridedDeps: { [string]: { [string]: string } } = {}

	for pkgName, versions in universe do
		if registryOverrides[pkgName] then
			local filtered: { semver.PackageVersion } = {}
			for _, v in versions do
				if semver.satisfies(v.version, registryOverrides[pkgName]) then
					table.insert(filtered, v)
				end
			end
			assert(
				#filtered > 0,
				`Override constrains '{pkgName}' to {semver.formatConstraint(registryOverrides[pkgName])}, but no matching version exists in the registry`
			)
			effective[pkgName] = filtered
		elseif sourceOverrideNames[pkgName] then
			continue
		else
			local rewritten: { semver.PackageVersion } = {}
			for _, v in versions do
				local newDeps: { [string]: semver.Requirement } = {}
				for alias, dep in v.dependencies do
					if registryOverrides[dep.name] then
						newDeps[alias] = table.freeze({
							name = dep.name,
							constraint = registryOverrides[dep.name],
							requiredBy = dep.requiredBy,
							aliasedAs = dep.aliasedAs,
						})
					elseif sourceOverrideNames[dep.name] then
						local vKey = `{v.name}@{v.versionString}`
						if not sourceOverridedDeps[vKey] then
							sourceOverridedDeps[vKey] = {}
						end
						sourceOverridedDeps[vKey][alias] = dep.name
					else
						newDeps[alias] = dep
					end
				end
				table.insert(
					rewritten,
					table.freeze({
						name = v.name,
						version = v.version,
						versionString = v.versionString,
						dependencies = table.freeze(newDeps),
					})
				)
			end
			effective[pkgName] = rewritten
		end
	end

	return effective, sourceOverridedDeps
end

local function pathDepsAreStale(lock: lockfile.Lockfile, rootDirectory: string): boolean
	for _, pkg in lock.packages do
		if pkg.sourceKind ~= "path" then
			continue
		end

		local depManifestPath = path.format(path.join(rootDirectory, pkg.installPath, "loom.config.luau"))
		if not fs.exists(depManifestPath) then
			return true
		end

		local ok, depManifest = pcall(manifest.parseFile, depManifestPath)
		if not ok then
			return true
		end

		for alias in depManifest.package.dependencies do
			if pkg.dependencies[alias] == nil then
				return true
			end
		end

		for alias in pkg.dependencies do
			if depManifest.package.dependencies[alias] == nil then
				return true
			end
		end

		for alias, depSpec in depManifest.package.dependencies do
			local recordedKey = pkg.dependencies[alias]
			if recordedKey == nil then
				continue
			end
			local recordedPkg = lock.packages[recordedKey]
			if recordedPkg == nil then
				return true
			end
			if recordedPkg.sourceKind ~= depSpec.sourceKind then
				return true
			end
			if depSpec.sourceKind == "github" then
				if recordedPkg.source ~= depSpec.source or recordedPkg.rev ~= depSpec.rev then
					return true
				end
			elseif depSpec.sourceKind == "path" then
				if recordedPkg.source ~= depSpec.source then
					return true
				end
			end
		end
	end
	return false
end

local function resolve(rootDirectory: string, universe: semver.Universe?, options: ResolveOptions?): lockfile.Lockfile
	local excludeDev = if options then options.excludeDev == true else false

	local rootManifestPath = getManifestPath(rootDirectory)
	if not fs.exists(rootManifestPath) then
		error(`Manifest file not found: {rootManifestPath}`)
	end

	local lockfilePath = getLockfilePath(rootDirectory)
	local rootManifest = manifest.parseFile(rootManifestPath)

	-- Attempt lockfile reuse
	local existingLock = lockfile.tryParseFile(lockfilePath)

	if options and options.locked and existingLock == nil then
		error("--locked: no lockfile found. Run `lute pkg install` first.")
	end

	if existingLock then
		local satisfied, reason = lockfile.satisfiesManifest(existingLock, rootManifest, excludeDev)

		if options and options.locked then
			if not satisfied then
				error(`--locked: lockfile does not satisfy manifest ({reason}). Run \`lute pkg install\` to update.`)
			end
			print("Lockfile up to date.")
			return existingLock
		end

		if satisfied and not pathDepsAreStale(existingLock, rootDirectory) then
			print("Lockfile up to date.")
			return existingLock
		end
	end

	-- Extract locked registry versions for soft preference during re-resolution.
	-- Skip packages that were previously overridden — removing an override should unlock the version.
	local lockedRegistryVersions: { [string]: string }? = nil
	if existingLock then
		lockedRegistryVersions = {}
		local previousOverrides = existingLock.overrides
		for _, pkg in existingLock.packages do
			if pkg.sourceKind == "registry" and pkg.rev then
				if previousOverrides and previousOverrides[pkg.name] then
					continue
				end
				(lockedRegistryVersions :: { [string]: string })[pkg.name] = pkg.rev
			end
		end
	end

	local queue: { manifest.DependencySpec } = {}
	local dependencies: { [string]: string } = {}
	local packages: { [string]: lockfile.LockfileDependency } = {}

	-- All registry solver inputs: root-level dependencies keyed by alias, transitive by "{pkgKey}:{dependencyAlias}".
	local registryRequirements: { [string]: semver.Requirement } = {}
	local registrySources: { [string]: string } = {}

	-- Root aliases that need a resolved key written back into `dependencies` after solving.
	local rootRegistryAliases: { string } = {}
	-- Per-package registry aliases that need keys written into their dependency table after solving.
	local unresolvedRegistryDependencies: { [string]: { [string]: string } } = {}
	-- Open (not yet finalized) dependency maps for unversioned packages; registry entries are filled in during versioned resolution.
	local openDependencies: { [string]: { [string]: string } } = {}

	for dependencyAlias, dependencySpec in rootManifest.package.dependencies do
		if dependencySpec.sourceKind == "registry" then
			registryRequirements[dependencyAlias] = {
				name = dependencySpec.name,
				constraint = semver.parseConstraint(dependencySpec.version),
				requiredBy = rootManifest.package.name,
				aliasedAs = if dependencyAlias ~= dependencySpec.name then dependencyAlias else nil,
			}

			registrySources[dependencySpec.name] = dependencySpec.source
			table.insert(rootRegistryAliases, dependencyAlias)
			continue
		end

		dependencies[dependencyAlias] = getKey(dependencySpec)
		table.insert(queue, dependencySpec)
	end

	if not excludeDev then
		for dependencyAlias, dependencySpec in rootManifest.package.devDependencies do
			if dependencySpec.sourceKind == "registry" then
				registryRequirements[dependencyAlias] = {
					name = dependencySpec.name,
					constraint = semver.parseConstraint(dependencySpec.version),
					requiredBy = rootManifest.package.name,
					aliasedAs = if dependencyAlias ~= dependencySpec.name then dependencyAlias else nil,
				}

				registrySources[dependencySpec.name] = dependencySpec.source
				table.insert(rootRegistryAliases, dependencyAlias)
				continue
			end

			dependencies[dependencyAlias] = getKey(dependencySpec)
			table.insert(queue, dependencySpec)
		end
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
						aliasedAs = if dependencyAlias ~= normalizedSpec.name then dependencyAlias else nil,
					}

					registrySources[normalizedSpec.name] = normalizedSpec.source

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

	-- Apply overrides: version pins replace constraints; source overrides redirect to path/github.
	local overrides = rootManifest.overrides
	local overriddenPackages: { [string]: semver.Requirement } = {}

	for overrideName, overrideSpec in overrides do
		removeRequirementsForPackage(registryRequirements, overrideName)

		if overrideSpec.sourceKind == "registry" then
			local overrideReq = {
				name = overrideName,
				constraint = semver.parseConstraint(overrideSpec.version),
				requiredBy = "override",
			}
			registryRequirements[`override:{overrideName}`] = overrideReq
			overriddenPackages[overrideName] = overrideReq

			if not registrySources[overrideName] then
				registrySources[overrideName] = overrideSpec.source
			end
		else
			local overrideKey = getKey(overrideSpec)

			for pkgKey, unresolvedAliases in unresolvedRegistryDependencies do
				for depAlias, registryName in unresolvedAliases do
					if registryName == overrideName then
						local packageDependencies = openDependencies[pkgKey]
						if packageDependencies then
							packageDependencies[depAlias] = overrideKey
						end
						unresolvedAliases[depAlias] = nil
					end
				end
			end

			-- Alias was removed from registryRequirements by the override; write override key directly.
			for i = #rootRegistryAliases, 1, -1 do
				if registryRequirements[rootRegistryAliases[i]] == nil then
					dependencies[rootRegistryAliases[i]] = overrideKey
					table.remove(rootRegistryAliases, i)
				end
			end

			if not packages[overrideKey] then
				local transitiveDependencies: { [string]: string } = {}
				openDependencies[overrideKey] = transitiveDependencies

				local installPath = fetchSource(overrideSpec, rootDirectory)
				local nestedManifestPath = getManifestPath(installPath)
				if fs.exists(nestedManifestPath) then
					local dependencyManifest = manifest.parseFile(nestedManifestPath)
					for dependencyAlias, dependencySpec in dependencyManifest.package.dependencies do
						local normalizedSpec = normalizePathDependency(dependencySpec, installPath, rootDirectory)

						if normalizedSpec.sourceKind == "registry" then
							registryRequirements[`{overrideKey}:{dependencyAlias}`] = {
								name = normalizedSpec.name,
								constraint = semver.parseConstraint(normalizedSpec.version),
								requiredBy = overrideKey,
								aliasedAs = if dependencyAlias ~= normalizedSpec.name then dependencyAlias else nil,
							}
							registrySources[normalizedSpec.name] = normalizedSpec.source
							if not unresolvedRegistryDependencies[overrideKey] then
								unresolvedRegistryDependencies[overrideKey] = {}
							end
							unresolvedRegistryDependencies[overrideKey][dependencyAlias] = normalizedSpec.name
							continue
						end

						transitiveDependencies[dependencyAlias] = getKey(normalizedSpec)
					end
				end

				packages[overrideKey] = table.freeze({
					name = overrideSpec.name,
					rev = if overrideSpec.sourceKind == "github" then overrideSpec.rev else nil,
					source = overrideSpec.source,
					sourceKind = overrideSpec.sourceKind,
					installPath = if overrideSpec.sourceKind == "path"
						then path.format(path.relative(rootDirectory, installPath))
						else store.toStorePath(overrideKey),
					dependencies = transitiveDependencies,
				})
			end
		end
	end

	-- Build a modified universe that respects overrides.
	local effectiveUniverse = universe
	local sourceOverridedDeps: { [string]: { [string]: string } } = {}
	if universe ~= nil and next(overrides) ~= nil then
		effectiveUniverse, sourceOverridedDeps = buildEffectiveUniverse(universe, overrides)
	end

	-- Versioned dependency resolution: solve registry dependencies and stitch them into the package graph.
	if next(registryRequirements) ~= nil then
		assert(effectiveUniverse ~= nil, "Registry dependencies require a universe to be provided")

		local resolution = semver.solve(effectiveUniverse, registryRequirements, lockedRegistryVersions)

		-- Build a lookup from package name to resolved version(s) for slot-keyed results.
		local versionsByPackageName = {}
		for _, pkgVersion in resolution do
			versionsByPackageName[pkgVersion.name] = pkgVersion
		end

		for _, pkgVersion in resolution do
			local name = pkgVersion.name
			local key = `{name}@{pkgVersion.versionString}`

			local transitiveDependencies: { [string]: string } = {}
			for alias, dependency in pkgVersion.dependencies do
				local resolvedVersion = versionsByPackageName[dependency.name]
				assert(resolvedVersion ~= nil, `Solver produced an incomplete resolution: missing '{dependency.name}'`)

				transitiveDependencies[alias] = `{dependency.name}@{resolvedVersion.versionString}`
			end

			-- Add back dependencies that were stripped for source overrides.
			if sourceOverridedDeps[key] then
				for alias, overriddenName in sourceOverridedDeps[key] do
					local overrideSpec = overrides[overriddenName]
					if overrideSpec then
						transitiveDependencies[alias] = getKey(overrideSpec)
					end
				end
			end

			packages[key] = table.freeze({
				name = name,
				rev = pkgVersion.versionString,
				source = registrySources[name] or name,
				sourceKind = "registry" :: "registry",
				installPath = store.toStorePath(key),
				dependencies = table.freeze(transitiveDependencies),
			})
		end

		-- Fill in pending registry dependency keys directly into the unversioned packages' dependency tables.
		for pkgKey, unresolvedAliases in unresolvedRegistryDependencies do
			local packageDependencies = openDependencies[pkgKey]
			for dependencyAlias, registryName in unresolvedAliases do
				local pkgVersion = versionsByPackageName[registryName]
				assert(pkgVersion ~= nil, `Solver did not resolve transitive registry dependency '{registryName}'`)
				packageDependencies[dependencyAlias] = `{registryName}@{pkgVersion.versionString}`
			end
		end

		-- Write root-level registry dependency aliases now that versions are resolved.
		for _, alias in rootRegistryAliases do
			local req = registryRequirements[alias] or overriddenPackages[alias]
			if req == nil then
				continue
			end
			local pkgVersion = versionsByPackageName[req.name]
			assert(pkgVersion ~= nil, `Solver did not resolve root dependency '{req.name}'`)
			dependencies[alias] = `{req.name}@{pkgVersion.versionString}`
		end
	end

	for _, packageDependencies in openDependencies do
		table.freeze(packageDependencies)
	end

	table.freeze(packages)
	table.freeze(dependencies)

	local serializedOverrides = lockfile.serializeOverrides(overrides)
	local frozenOverrides: { [string]: string }? = if next(serializedOverrides)
		then table.freeze(serializedOverrides)
		else nil

	local lock: lockfile.Lockfile = table.freeze({
		version = if frozenOverrides then 4 else 3,
		packages = packages,
		dependencies = dependencies,
		overrides = frozenOverrides,
	})

	fs.writeStringToFile(lockfilePath, `return {pp(lock)}\n`)

	return lock
end

return {
	resolve = resolve,
}
