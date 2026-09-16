local fs = require("@std/fs")
local github = require("./github")
local lockfile = require("./lockfile")
local path = require("@std/path")
local pp = require("@batteries/pp")
local manifest = require("./manifest")
local registry = require("./registry")
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

type RootRegistryAlias = {
	read alias: string,
	read name: string,
}

type ResolutionState = {
	queue: { manifest.DependencySpec },
	queueIndex: number,
	dependencies: { [string]: string },
	packages: { [string]: lockfile.LockfileDependency },
	registryRequirements: { [string]: semver.Requirement },
	-- Maps a source-qualified package identity to its name in the registry.
	registrySources: { [string]: string },
	-- Maps an unqualified registry package name to all source-qualified identities seen for it.
	registryIdentitiesBySource: { [string]: { [string]: boolean } },
	rootRegistryAliases: { RootRegistryAlias },
	unresolvedRegistryDependencies: { [string]: { [string]: string } },
	openDependencies: { [string]: { [string]: string } },
	registryUrlByPackage: { [string]: string },
}

local function getRegistryPackageName(name: string, registryUrl: string?): string
	if registryUrl == nil then
		return name
	end

	return store.getRegistryPackageName(name, registryUrl)
end

local function registerRegistryPackage(
	registrySources: { [string]: string },
	registryIdentitiesBySource: { [string]: { [string]: boolean } },
	registryUrlByPackage: { [string]: string },
	name: string,
	registryUrl: string?
): string
	local registryPackageName = getRegistryPackageName(name, registryUrl)
	registrySources[registryPackageName] = name

	if not registryIdentitiesBySource[name] then
		registryIdentitiesBySource[name] = {}
	end
	registryIdentitiesBySource[name][registryPackageName] = true

	if registryUrl then
		registryUrlByPackage[registryPackageName] = registryUrl
	end

	return registryPackageName
end

local function getRegistryLockKey(state: ResolutionState, registryPackageName: string, version: string): string
	local source = state.registrySources[registryPackageName] or registryPackageName
	local identities = state.registryIdentitiesBySource[source]
	local identityCount = 0
	if identities then
		for _ in identities do
			identityCount += 1
		end
	end

	local packageName = if identityCount > 1 then registryPackageName else source
	return `{packageName}@{version}`
end

local function removeRequirementsForPackage(
	registryRequirements: { [string]: semver.Requirement },
	registrySources: { [string]: string },
	packageName: string
)
	for reqKey, req in registryRequirements do
		if registrySources[req.name] == packageName then
			registryRequirements[reqKey] = nil
		end
	end
end

local function collectSourcePackageDependencies(
	key: string,
	installPath: string,
	rootDirectory: string,
	transitiveDependencies: { [string]: string },
	queue: { manifest.DependencySpec },
	registryRequirements: { [string]: semver.Requirement },
	registrySources: { [string]: string },
	registryIdentitiesBySource: { [string]: { [string]: boolean } },
	unresolvedRegistryDependencies: { [string]: { [string]: string } },
	registryUrlByPackage: { [string]: string }
)
	local nestedManifestPath = getManifestPath(installPath)
	if not fs.exists(nestedManifestPath) then
		return
	end

	local dependencyManifest = manifest.parseFile(nestedManifestPath)

	for dependencyAlias, dependencySpec in dependencyManifest.package.dependencies do
		local normalizedSpec = normalizePathDependency(dependencySpec, installPath, rootDirectory)

		if normalizedSpec.sourceKind == "registry" then
			assert(
				dependencyManifest.registry ~= nil,
				`Package '{key}' has registry dependency '{normalizedSpec.name}' but no 'registry' field in its manifest.`
			)

			local registryPackageName = registerRegistryPackage(
				registrySources,
				registryIdentitiesBySource,
				registryUrlByPackage,
				normalizedSpec.name,
				dependencyManifest.registry
			)

			registryRequirements[`{key}:{dependencyAlias}`] = {
				name = registryPackageName,
				constraint = semver.parseConstraint(normalizedSpec.version),
				requiredBy = key,
				aliasedAs = if dependencyAlias ~= normalizedSpec.name then dependencyAlias else nil,
			}

			if not unresolvedRegistryDependencies[key] then
				unresolvedRegistryDependencies[key] = {}
			end

			unresolvedRegistryDependencies[key][dependencyAlias] = registryPackageName
			continue
		end

		transitiveDependencies[dependencyAlias] = getKey(normalizedSpec)
		table.insert(queue, normalizedSpec)
	end
end

local function resolveSourcePackage(
	spec: manifest.DependencySpec,
	rootDirectory: string,
	packages: { [string]: lockfile.LockfileDependency },
	openDependencies: { [string]: { [string]: string } },
	queue: { manifest.DependencySpec },
	registryRequirements: { [string]: semver.Requirement },
	registrySources: { [string]: string },
	registryIdentitiesBySource: { [string]: { [string]: boolean } },
	unresolvedRegistryDependencies: { [string]: { [string]: string } },
	registryUrlByPackage: { [string]: string }
): string
	local key = getKey(spec)

	if packages[key] then
		if hasConflict(packages[key], spec) then
			error(
				`Source mismatch for package '{spec.name}':\n`
					.. `  resolved: {packages[key].source} ({packages[key].sourceKind})\n`
					.. `  incoming: {spec.source} ({spec.sourceKind})\n`
					.. `Both resolve to '{key}' but from different sources.`
			)
		end

		return key
	end

	local transitiveDependencies: { [string]: string } = {}
	openDependencies[key] = transitiveDependencies

	local installPath = fetchSource(spec, rootDirectory)

	collectSourcePackageDependencies(
		key,
		installPath,
		rootDirectory,
		transitiveDependencies,
		queue,
		registryRequirements,
		registrySources,
		registryIdentitiesBySource,
		unresolvedRegistryDependencies,
		registryUrlByPackage
	)

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

	return key
end

local function processSourceQueue(state: ResolutionState, rootDirectory: string)
	while state.queueIndex <= #state.queue do
		local spec = state.queue[state.queueIndex]
		state.queueIndex += 1

		resolveSourcePackage(
			spec,
			rootDirectory,
			state.packages,
			state.openDependencies,
			state.queue,
			state.registryRequirements,
			state.registrySources,
			state.registryIdentitiesBySource,
			state.unresolvedRegistryDependencies,
			state.registryUrlByPackage
		)
	end
end

local function buildEffectiveUniverse(
	universe: semver.Universe,
	overrides: { [string]: manifest.DependencySpec },
	registrySources: { [string]: string }
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
		local sourceName = registrySources[pkgName] or pkgName
		if registryOverrides[sourceName] then
			local filtered: { semver.PackageVersion } = {}
			for _, v in versions do
				if semver.satisfies(v.version, registryOverrides[sourceName]) then
					table.insert(filtered, v)
				end
			end
			assert(
				#filtered > 0,
				`Override constrains '{sourceName}' to {semver.formatConstraint(registryOverrides[sourceName])}, but no matching version exists in the registry`
			)
			effective[pkgName] = filtered
		elseif sourceOverrideNames[sourceName] then
			continue
		else
			local rewritten: { semver.PackageVersion } = {}
			for _, v in versions do
				local newDeps: { [string]: semver.Requirement } = {}
				for alias, dep in v.dependencies do
					local dependencySource = registrySources[dep.name] or dep.name
					if registryOverrides[dependencySource] then
						newDeps[alias] = table.freeze({
							name = dep.name,
							constraint = registryOverrides[dependencySource],
							requiredBy = dep.requiredBy,
							aliasedAs = dep.aliasedAs,
						})
					elseif sourceOverrideNames[dependencySource] then
						local vKey = `{v.name}@{v.versionString}`
						if not sourceOverridedDeps[vKey] then
							sourceOverridedDeps[vKey] = {}
						end
						sourceOverridedDeps[vKey][alias] = dependencySource
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

local function pathDepsAreStale(
	lock: lockfile.Lockfile,
	rootDirectory: string,
	overrides: { [string]: manifest.DependencySpec }
): boolean
	for _, pkg in lock.packages do
		if pkg.sourceKind ~= "path" then
			continue
		end

		local packageInstallPath = path.format(path.join(rootDirectory, pkg.installPath))
		local depManifestPath = path.format(path.join(packageInstallPath, "loom.config.luau"))
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
			local normalizeOk, normalizedDepSpec =
				pcall(normalizePathDependency, depSpec, packageInstallPath, rootDirectory)
			if not normalizeOk then
				return true
			end
			depSpec = overrides[(normalizedDepSpec :: manifest.DependencySpec).name] or normalizedDepSpec

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
			elseif depSpec.sourceKind == "registry" then
				if recordedPkg.source ~= depSpec.source or recordedPkg.registry ~= depManifest.registry then
					return true
				end
			end
		end
	end
	return false
end

local function tryReuseLockfile(
	rootManifest: manifest.ProjectManifest,
	lockfilePath: string,
	rootDirectory: string,
	excludeDev: boolean,
	options: ResolveOptions?
): (lockfile.Lockfile?, { [string]: string }?)
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
			return existingLock, nil
		end

		if satisfied and not pathDepsAreStale(existingLock, rootDirectory, rootManifest.overrides) then
			return existingLock, nil
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
				local packageName = getRegistryPackageName(pkg.name, pkg.registry)
				local lockedVersions = lockedRegistryVersions :: { [string]: string }
				lockedVersions[packageName] = pkg.rev
			end
		end
	end

	return nil, lockedRegistryVersions
end

local function collectRootDependency(
	state: ResolutionState,
	rootPackageName: string,
	dependencyAlias: string,
	dependencySpec: manifest.DependencySpec,
	registryUrl: string?
)
	if dependencySpec.sourceKind == "registry" then
		local registryPackageName = registerRegistryPackage(
			state.registrySources,
			state.registryIdentitiesBySource,
			state.registryUrlByPackage,
			dependencySpec.name,
			registryUrl
		)
		state.registryRequirements[dependencyAlias] = {
			name = registryPackageName,
			constraint = semver.parseConstraint(dependencySpec.version),
			requiredBy = rootPackageName,
			aliasedAs = if dependencyAlias ~= dependencySpec.name then dependencyAlias else nil,
		}

		table.insert(state.rootRegistryAliases, { alias = dependencyAlias, name = registryPackageName })
		return
	end

	state.dependencies[dependencyAlias] = getKey(dependencySpec)
	table.insert(state.queue, dependencySpec)
end

local function collectRootDependencies(rootManifest: manifest.ProjectManifest, excludeDev: boolean): ResolutionState
	local state: ResolutionState = {
		queue = {},
		queueIndex = 1,
		dependencies = {},
		packages = {},
		registryRequirements = {},
		registrySources = {},
		registryIdentitiesBySource = {},
		rootRegistryAliases = {},
		unresolvedRegistryDependencies = {},
		openDependencies = {},
		registryUrlByPackage = {},
	}

	for dependencyAlias, dependencySpec in rootManifest.package.dependencies do
		collectRootDependency(state, rootManifest.package.name, dependencyAlias, dependencySpec, rootManifest.registry)
	end

	if not excludeDev then
		for dependencyAlias, dependencySpec in rootManifest.package.devDependencies do
			collectRootDependency(
				state,
				rootManifest.package.name,
				dependencyAlias,
				dependencySpec,
				rootManifest.registry
			)
		end
	end

	return state
end

local function applyOverrides(
	state: ResolutionState,
	overrides: { [string]: manifest.DependencySpec },
	rootDirectory: string,
	rootRegistryUrl: string?
): { [string]: semver.Requirement }
	local overriddenPackages: { [string]: semver.Requirement } = {}

	for overrideName, overrideSpec in overrides do
		removeRequirementsForPackage(state.registryRequirements, state.registrySources, overrideName)

		if overrideSpec.sourceKind == "registry" then
			local registryPackageName = registerRegistryPackage(
				state.registrySources,
				state.registryIdentitiesBySource,
				state.registryUrlByPackage,
				overrideSpec.source,
				rootRegistryUrl
			)
			local overrideReq = {
				name = registryPackageName,
				constraint = semver.parseConstraint(overrideSpec.version),
				requiredBy = "override",
			}
			state.registryRequirements[`override:{overrideName}`] = overrideReq
			overriddenPackages[overrideName] = overrideReq

			-- The original requirement may have come from a different registry. Point
			-- pending source-package dependencies at the override's registry identity
			-- so the resolved version can be stitched into their dependency tables.
			for _, unresolvedAliases in state.unresolvedRegistryDependencies do
				for depAlias, registryName in unresolvedAliases do
					if state.registrySources[registryName] == overrideName then
						unresolvedAliases[depAlias] = registryPackageName
					end
				end
			end
		else
			local overrideKey = resolveSourcePackage(
				overrideSpec,
				rootDirectory,
				state.packages,
				state.openDependencies,
				state.queue,
				state.registryRequirements,
				state.registrySources,
				state.registryIdentitiesBySource,
				state.unresolvedRegistryDependencies,
				state.registryUrlByPackage
			)

			for pkgKey, unresolvedAliases in state.unresolvedRegistryDependencies do
				for depAlias, registryName in unresolvedAliases do
					if state.registrySources[registryName] == overrideName then
						local packageDependencies = state.openDependencies[pkgKey]
						if packageDependencies then
							packageDependencies[depAlias] = overrideKey
						end
						unresolvedAliases[depAlias] = nil
					end
				end
			end

			-- Alias was removed from registryRequirements by the override; write override key directly.
			for i = #state.rootRegistryAliases, 1, -1 do
				local rootAlias = state.rootRegistryAliases[i]
				if state.registrySources[rootAlias.name] == overrideName then
					state.dependencies[rootAlias.alias] = overrideKey
					table.remove(state.rootRegistryAliases, i)
				end
			end
		end
	end

	return overriddenPackages
end

local function namespaceRegistryUniverse(
	universe: semver.Universe,
	registryUrl: string,
	state: ResolutionState
): semver.Universe
	local namespaced: semver.Universe = {}
	local visited: { [string]: boolean } = {}

	local function namespacePackage(source: string)
		local packageName = registerRegistryPackage(
			state.registrySources,
			state.registryIdentitiesBySource,
			state.registryUrlByPackage,
			source,
			registryUrl
		)
		if visited[packageName] then
			return
		end
		visited[packageName] = true

		local versions = universe[source]
		if versions == nil then
			return
		end

		local transformed: { semver.PackageVersion } = {}
		for _, version in versions do
			local dependencies: { [string]: semver.Requirement } = {}
			for alias, dependency in version.dependencies do
				local dependencyName = registerRegistryPackage(
					state.registrySources,
					state.registryIdentitiesBySource,
					state.registryUrlByPackage,
					dependency.name,
					registryUrl
				)
				dependencies[alias] = table.freeze({
					name = dependencyName,
					constraint = dependency.constraint,
					requiredBy = dependency.requiredBy,
					aliasedAs = dependency.aliasedAs,
				})
			end

			table.insert(
				transformed,
				table.freeze({
					name = packageName,
					version = version.version,
					versionString = version.versionString,
					dependencies = table.freeze(dependencies),
				})
			)
		end
		namespaced[packageName] = transformed

		for _, version in versions do
			for _, dependency in version.dependencies do
				namespacePackage(dependency.name)
			end
		end
	end

	for source in universe do
		namespacePackage(source)
	end

	return namespaced
end

local function resolveRegistryDependencies(
	state: ResolutionState,
	overriddenPackages: { [string]: semver.Requirement },
	universe: semver.Universe?,
	overrides: { [string]: manifest.DependencySpec },
	lockedRegistryVersions: { [string]: string }?
)
	-- Versioned dependency resolution: solve registry dependencies and stitch them into the package graph.
	if next(state.registryRequirements) == nil then
		return
	end

	-- Build or fetch the universe.
	local effectiveUniverse: semver.Universe
	local sourceOverridedDeps: { [string]: { [string]: string } } = {}

	if universe == nil then
		local packagesByRegistryUrl: { [string]: { { name: string, source: string } } } = {}
		local seen: { [string]: boolean } = {}

		for _, req in state.registryRequirements do
			if seen[req.name] then
				continue
			end
			seen[req.name] = true

			local url = state.registryUrlByPackage[req.name]
			assert(
				url ~= nil,
				`No registry configured for package '{req.name}'. Add a 'registry' field to your loom.config.luau.`
			)

			if not packagesByRegistryUrl[url] then
				packagesByRegistryUrl[url] = {}
			end
			table.insert(packagesByRegistryUrl[url], {
				name = state.registrySources[req.name] or req.name,
				source = state.registrySources[req.name] or req.name,
			})
		end

		effectiveUniverse = {}
		for url, names in packagesByRegistryUrl do
			local partial = registry.fetchUniverse(url, names)
			local namespaced = namespaceRegistryUniverse(partial, url, state)
			for name, versions in namespaced do
				effectiveUniverse[name] = versions
			end
		end
	else
		effectiveUniverse = table.clone(universe)
		local namespacedUrls: { [string]: boolean } = {}
		for _, req in state.registryRequirements do
			local url = state.registryUrlByPackage[req.name]
			if url and not namespacedUrls[url] then
				local namespaced = namespaceRegistryUniverse(universe, url, state)
				for name, versions in namespaced do
					effectiveUniverse[name] = versions
				end
				namespacedUrls[url] = true
			end
		end
	end

	-- Build a modified universe that respects overrides.
	if next(overrides) ~= nil then
		effectiveUniverse, sourceOverridedDeps =
			buildEffectiveUniverse(effectiveUniverse, overrides, state.registrySources)
	end

	local resolution = semver.solve(effectiveUniverse, state.registryRequirements, lockedRegistryVersions)

	-- Build a lookup from package name to resolved version(s) for slot-keyed results.
	local versionsByPackageName = {}
	for _, pkgVersion in resolution do
		versionsByPackageName[pkgVersion.name] = pkgVersion
	end

	for _, pkgVersion in resolution do
		local registryPackageName = pkgVersion.name
		local key = getRegistryLockKey(state, registryPackageName, pkgVersion.versionString)
		local registryUrl = state.registryUrlByPackage[registryPackageName]
		local storeKey = if registryUrl then store.getRegistryPackageKey(key, registryUrl) else key

		local transitiveDependencies: { [string]: string } = {}
		for alias, dependency in pkgVersion.dependencies do
			local resolvedVersion = versionsByPackageName[dependency.name]
			assert(resolvedVersion ~= nil, `Solver produced an incomplete resolution: missing '{dependency.name}'`)

			transitiveDependencies[alias] = getRegistryLockKey(state, dependency.name, resolvedVersion.versionString)
		end

		-- Add back dependencies that were stripped for source overrides.
		local solverKey = `{registryPackageName}@{pkgVersion.versionString}`
		if sourceOverridedDeps[solverKey] then
			for alias, overriddenName in sourceOverridedDeps[solverKey] do
				local overrideSpec = overrides[overriddenName]
				if overrideSpec then
					transitiveDependencies[alias] = getKey(overrideSpec)
				end
			end
		end

		state.packages[key] = table.freeze({
			name = state.registrySources[registryPackageName] or registryPackageName,
			rev = pkgVersion.versionString,
			source = state.registrySources[registryPackageName] or registryPackageName,
			sourceKind = "registry" :: "registry",
			installPath = store.toStorePath(storeKey),
			dependencies = table.freeze(transitiveDependencies),
			registry = registryUrl,
		})
	end

	-- Fill in pending registry dependency keys directly into the unversioned packages' dependency tables.
	for pkgKey, unresolvedAliases in state.unresolvedRegistryDependencies do
		local packageDependencies = state.openDependencies[pkgKey]
		for dependencyAlias, registryName in unresolvedAliases do
			local pkgVersion = versionsByPackageName[registryName]
			assert(pkgVersion ~= nil, `Solver did not resolve transitive registry dependency '{registryName}'`)
			packageDependencies[dependencyAlias] = getRegistryLockKey(state, registryName, pkgVersion.versionString)
		end
	end

	-- Write root-level registry dependency aliases now that versions are resolved.
	for _, rootAlias in state.rootRegistryAliases do
		local sourceName = state.registrySources[rootAlias.name] or rootAlias.name
		local req = state.registryRequirements[rootAlias.alias] or overriddenPackages[sourceName]
		if req == nil then
			continue
		end
		local pkgVersion = versionsByPackageName[req.name]
		assert(pkgVersion ~= nil, `Solver did not resolve root dependency '{req.name}'`)
		state.dependencies[rootAlias.alias] = getRegistryLockKey(state, req.name, pkgVersion.versionString)
	end
end

local function buildLockfile(
	state: ResolutionState,
	overrides: { [string]: manifest.DependencySpec },
	lockfilePath: string,
	registryUrl: string?
): lockfile.Lockfile
	for _, packageDependencies in state.openDependencies do
		table.freeze(packageDependencies)
	end

	table.freeze(state.packages)
	table.freeze(state.dependencies)

	local serializedOverrides = lockfile.serializeOverrides(overrides)
	local frozenOverrides: { [string]: string }? = if next(serializedOverrides)
		then table.freeze(serializedOverrides)
		else nil

	local lock: lockfile.Lockfile = table.freeze({
		version = 3,
		packages = state.packages,
		dependencies = state.dependencies,
		overrides = frozenOverrides,
		registry = registryUrl,
	})

	fs.writeStringToFile(lockfilePath, `return {pp(lock)}\n`)

	return lock
end

local function resolve(rootDirectory: string, universe: semver.Universe?, options: ResolveOptions?): lockfile.Lockfile
	local excludeDev = if options then options.excludeDev == true else false

	local rootManifestPath = getManifestPath(rootDirectory)
	if not fs.exists(rootManifestPath) then
		error(`Manifest file not found: {rootManifestPath}`)
	end

	local lockfilePath = getLockfilePath(rootDirectory)
	local rootManifest = manifest.parseFile(rootManifestPath)

	local reusedLock, lockedRegistryVersions =
		tryReuseLockfile(rootManifest, lockfilePath, rootDirectory, excludeDev, options)
	if reusedLock then
		return reusedLock
	end

	local state = collectRootDependencies(rootManifest, excludeDev)
	processSourceQueue(state, rootDirectory)

	local overrides = rootManifest.overrides
	local overriddenPackages = applyOverrides(state, overrides, rootDirectory, rootManifest.registry)
	processSourceQueue(state, rootDirectory)

	resolveRegistryDependencies(state, overriddenPackages, universe, overrides, lockedRegistryVersions)

	return buildLockfile(state, overrides, lockfilePath, rootManifest.registry)
end

return {
	resolve = resolve,
}
