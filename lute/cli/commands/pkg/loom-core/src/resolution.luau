local fs = require("@std/fs")
local github = require("./github")
local lockfile = require("./lockfile")
local path = require("@std/path")
local pp = require("@batteries/pp")
local manifest = require("./manifest")
local registry = require("./registry")
local registryUrlUtil = require("./registryurl")
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
		if spec.target ~= nil then
			return `{spec.name}@{spec.rev}#{spec.target}`
		end
		return `{spec.name}@{spec.rev}`
	end

	return spec.name
end

local function hasConflict(
	resolved: lockfile.LockfileDependency,
	incoming: manifest.DependencySpec,
	rootDirectory: string
): boolean
	return not lockfile.isSameSource(resolved, incoming, rootDirectory)
end

local function selectGitHubTarget(spec: manifest.GitHubDependencySpec, sourcePath: string): string
	if spec.target == nil then
		return sourcePath
	end

	assert(not path.isAbsolute(spec.target), `Target for package '{spec.name}' must be a relative path`)
	local targetPath = path.format(path.resolve(sourcePath, spec.target))
	local relativeTarget = path.format(path.relative(sourcePath, targetPath))
	assert(
		relativeTarget ~= ".." and string.sub(relativeTarget, 1, 3) ~= "../",
		`Target for package '{spec.name}' must be contained within its source`
	)
	if not fs.exists(targetPath) then
		error(`Target directory not found: {targetPath} (for package '{spec.name}')`)
	end

	return targetPath
end

type SourceLocation = {
	-- the package's location in store
	read directory: string,
	-- the git repo's bound
	read checkout: { read root: string, read spec: manifest.GitHubDependencySpec }?,
}

-- Converts path dependency in git package to a github dependency
-- if dependency not a path dependency / the parent package not a github package, spec unchanged
-- otherwise resolves declared path from the selected package directory (target) as long as it exist and is in the original repo
local function resolveDependencySource(spec: manifest.DependencySpec, from: SourceLocation): manifest.DependencySpec
	local checkout = from.checkout
	if spec.sourceKind ~= "path" or checkout == nil then
		return spec
	end

	if not fs.exists(spec.directory) then
		error(`Path dependency directory not found: {spec.directory} (for package '{spec.name}')`)
	end

	local target = path.relative(checkout.root, spec.directory)
	if target.parts[1] == ".." then
		error(
			`Path dependency '{spec.name}' leaves its GitHub checkout {checkout.spec.source}; use a GitHub or registry dependency instead`
		)
	end

	return table.freeze({
		name = spec.name,
		sourceKind = "github" :: "github",
		source = checkout.spec.source,
		rev = checkout.spec.rev,
		target = if #target.parts == 0 then nil else path.format(target),
	})
end

local function fetchSource(spec: manifest.DependencySpec, rootDirectory: string): SourceLocation
	if spec.sourceKind == "path" then
		if not fs.exists(spec.directory) then
			error(`Path dependency directory not found: {spec.directory} (for package '{spec.name}')`)
		end
		return { directory = spec.directory }
	elseif spec.sourceKind == "github" then
		store.ensureStoreDirectory()

		local key = store.getGitHubCheckoutKey(spec.source, spec.rev)
		local sourcePath = store.getPackagePath(key)
		if not store.hasPackage(key) then
			github.installPackage(spec.source, spec.rev, sourcePath)
		end

		return {
			directory = selectGitHubTarget(spec, sourcePath),
			checkout = { root = sourcePath, spec = spec },
		}
	else
		error(`Unsupported source kind: {spec.sourceKind} for package {spec.name}`)
	end
end

local function getSourceInstallPath(spec: manifest.DependencySpec, rootDirectory: string, selectedPath: string): string
	if spec.sourceKind == "path" then
		return path.format(path.relative(rootDirectory, selectedPath))
	end

	assert(spec.sourceKind == "github", `Unsupported source kind: {spec.sourceKind} for package {spec.name}`)
	return store.getGitHubInstallPath(spec.source, spec.rev, spec.target)
end

export type ResolveOptions = {
	read excludeDev: boolean?,
	read locked: boolean?,
}

type RootRegistryAlias = {
	read alias: string,
	read name: string,
}

type QueuedSource = {
	read spec: manifest.DependencySpec,
	-- Should only be true if dependency is a direct path dependency of a virtual
	-- package root, in which case its dev dependencies should be resolved. When
	-- false function as before
	read includeDev: boolean,
}

type ResolutionState = {
	queue: { QueuedSource },
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

	return store.qualifyRegistryKey(name, registryUrl)
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

local function assertNotVirtualPackage(key: string, packageManifest: manifest.ProjectManifest)
	if packageManifest.package.name == nil then
		error(
			`'{key}' points at a virtual package, which cannot be depended on; point at one of its packages' directories instead (for GitHub, set 'target')`
		)
	end
end

local function collectSourcePackageDependencies(
	key: string,
	location: SourceLocation,
	rootDirectory: string,
	overrides: { [string]: manifest.DependencySpec },
	rootRegistryUrl: string?,
	transitiveDependencies: { [string]: string },
	queue: { QueuedSource },
	registryRequirements: { [string]: semver.Requirement },
	registrySources: { [string]: string },
	registryIdentitiesBySource: { [string]: { [string]: boolean } },
	unresolvedRegistryDependencies: { [string]: { [string]: string } },
	registryUrlByPackage: { [string]: string },
	includeDev: boolean
)
	local nestedManifestPath = getManifestPath(location.directory)
	if not fs.exists(nestedManifestPath) then
		error(`Package '{key}' does not contain a manifest: {nestedManifestPath}`)
	end

	local dependencyManifest = manifest.parseFile(nestedManifestPath)
	assertNotVirtualPackage(key, dependencyManifest)

	local function collectDependencies(dependencies: { [string]: manifest.DependencySpec })
		for dependencyAlias, dependencySpec in dependencies do
			local sourceSpec = resolveDependencySource(dependencySpec, location)
			local overrideSpec = overrides[sourceSpec.name]
			local effectiveSpec = overrideSpec or sourceSpec

			if sourceSpec.sourceKind == "registry" then
				assert(
					dependencyManifest.registry ~= nil,
					`Package '{key}' has registry dependency '{sourceSpec.name}' but no 'registry' field in its manifest.`
				)
			end

			if effectiveSpec.sourceKind == "registry" then
				local effectiveRegistryUrl = if overrideSpec then rootRegistryUrl else dependencyManifest.registry
				local registryPackageName = registerRegistryPackage(
					registrySources,
					registryIdentitiesBySource,
					registryUrlByPackage,
					effectiveSpec.name,
					effectiveRegistryUrl
				)

				registryRequirements[`{key}:{dependencyAlias}`] = {
					name = registryPackageName,
					constraint = semver.parseConstraint(effectiveSpec.version),
					requiredBy = key,
					aliasedAs = if dependencyAlias ~= effectiveSpec.name then dependencyAlias else nil,
				}

				if not unresolvedRegistryDependencies[key] then
					unresolvedRegistryDependencies[key] = {}
				end

				unresolvedRegistryDependencies[key][dependencyAlias] = registryPackageName
			else
				transitiveDependencies[dependencyAlias] = getKey(effectiveSpec)
				table.insert(queue, { spec = effectiveSpec, includeDev = false })
			end
		end
	end

	collectDependencies(dependencyManifest.package.dependencies)
	if includeDev then
		collectDependencies(dependencyManifest.package.devDependencies)
	end
end

local function resolveSourcePackage(
	spec: manifest.DependencySpec,
	rootDirectory: string,
	packages: { [string]: lockfile.LockfileDependency },
	openDependencies: { [string]: { [string]: string } },
	queue: { QueuedSource },
	registryRequirements: { [string]: semver.Requirement },
	registrySources: { [string]: string },
	registryIdentitiesBySource: { [string]: { [string]: boolean } },
	unresolvedRegistryDependencies: { [string]: { [string]: string } },
	registryUrlByPackage: { [string]: string },
	overrides: { [string]: manifest.DependencySpec },
	rootRegistryUrl: string?,
	includeDev: boolean
): string
	local key = getKey(spec)

	if packages[key] then
		if hasConflict(packages[key], spec, rootDirectory) then
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

	local location = fetchSource(spec, rootDirectory)

	collectSourcePackageDependencies(
		key,
		location,
		rootDirectory,
		overrides,
		rootRegistryUrl,
		transitiveDependencies,
		queue,
		registryRequirements,
		registrySources,
		registryIdentitiesBySource,
		unresolvedRegistryDependencies,
		registryUrlByPackage,
		includeDev
	)

	packages[key] = table.freeze({
		name = spec.name,
		rev = if spec.sourceKind == "github" then spec.rev else nil,
		source = if spec.sourceKind == "path"
			then path.format(path.relative(rootDirectory, spec.directory))
			else spec.source,
		sourceKind = spec.sourceKind,
		target = if spec.sourceKind == "github" then spec.target else nil,
		installPath = getSourceInstallPath(spec, rootDirectory, location.directory),
		dependencies = transitiveDependencies,
	})

	return key
end

local function processSourceQueue(
	state: ResolutionState,
	rootDirectory: string,
	overrides: { [string]: manifest.DependencySpec },
	rootRegistryUrl: string?
)
	while state.queueIndex <= #state.queue do
		local queued = state.queue[state.queueIndex]
		state.queueIndex += 1

		resolveSourcePackage(
			queued.spec,
			rootDirectory,
			state.packages,
			state.openDependencies,
			state.queue,
			state.registryRequirements,
			state.registrySources,
			state.registryIdentitiesBySource,
			state.unresolvedRegistryDependencies,
			state.registryUrlByPackage,
			overrides,
			rootRegistryUrl,
			queued.includeDev
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
	overrides: { [string]: manifest.DependencySpec },
	rootRegistryUrl: string?,
	rootLocalDevPackageKeys: { [string]: boolean }
): boolean
	for key, pkg in lock.packages do
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

		local expectedDependencies: { [string]: manifest.DependencySpec } = {}
		for alias, spec in depManifest.package.dependencies do
			expectedDependencies[alias] = spec
		end
		if rootLocalDevPackageKeys[key] then
			for alias, spec in depManifest.package.devDependencies do
				expectedDependencies[alias] = spec
			end
		end

		for alias in expectedDependencies do
			if pkg.dependencies[alias] == nil then
				return true
			end
		end

		for alias in pkg.dependencies do
			if expectedDependencies[alias] == nil then
				return true
			end
		end

		for alias, depSpec in expectedDependencies do
			local overrideSpec = overrides[depSpec.name]
			depSpec = overrideSpec or depSpec

			local recordedKey = pkg.dependencies[alias]
			if recordedKey == nil then
				continue
			end
			local recordedPkg = lock.packages[recordedKey]
			if recordedPkg == nil then
				return true
			end
			if not lockfile.isSameSource(recordedPkg, depSpec, rootDirectory) then
				return true
			end
			if depSpec.sourceKind == "registry" then
				local registryUrl = if overrideSpec then rootRegistryUrl else depManifest.registry
				if
					recordedPkg.source ~= depSpec.source
					or not registryUrlUtil.equals(recordedPkg.registry, registryUrl)
				then
					return true
				end

				local constraint = semver.parseConstraint(depSpec.version)
				local lockedVersion = semver.tryParse(recordedPkg.rev :: string)
				if lockedVersion == nil or not semver.satisfies(lockedVersion, constraint) then
					return true
				end
			end
		end
	end
	return false
end

local function getRootLocalDevPackageKeys(
	rootManifest: manifest.ProjectManifest,
	excludeDev: boolean
): { [string]: boolean }
	local result: { [string]: boolean } = {}
	-- exclude dev or not root (has a name) no dev dependency
	if rootManifest.package.name ~= nil or excludeDev then
		return result
	end

	-- resolved graph should include dev dependencies for direct root dependencies whose effective spec (after overrides) are path dependency
	local function collectDependencies(dependencies: { [string]: manifest.DependencySpec })
		for _, spec in dependencies do
			local effectiveSpec = rootManifest.overrides[spec.name] or spec
			if effectiveSpec.sourceKind == "path" then
				result[getKey(effectiveSpec)] = true
			end
		end
	end

	-- collects the dev dependencies from both root dependencies and root dev dependencies
	collectDependencies(rootManifest.package.dependencies)
	collectDependencies(rootManifest.package.devDependencies)
	return result
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
		local satisfied, reason = lockfile.satisfiesManifest(existingLock, rootManifest, rootDirectory, excludeDev)
		local pathsAreStale = pathDepsAreStale(
			existingLock,
			rootDirectory,
			rootManifest.overrides,
			rootManifest.registry,
			getRootLocalDevPackageKeys(rootManifest, excludeDev)
		)

		if options and options.locked then
			if not satisfied then
				error(`--locked: lockfile does not satisfy manifest ({reason}). Run \`lute pkg install\` to update.`)
			end
			if pathsAreStale then
				error("--locked: lockfile does not satisfy path dependencies. Run `lute pkg install` to update.")
			end
			return existingLock, nil
		end

		if satisfied and not pathsAreStale then
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
				local _lockedVersions = lockedRegistryVersions :: { [string]: string }
				_lockedVersions[packageName] = pkg.rev
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
	registryUrl: string?,
	overrides: { [string]: manifest.DependencySpec },
	includeDev: boolean
)
	local effectiveSpec = overrides[dependencySpec.name] or dependencySpec

	if effectiveSpec.sourceKind == "registry" then
		local registryPackageName = registerRegistryPackage(
			state.registrySources,
			state.registryIdentitiesBySource,
			state.registryUrlByPackage,
			effectiveSpec.name,
			registryUrl
		)
		state.registryRequirements[dependencyAlias] = {
			name = registryPackageName,
			constraint = semver.parseConstraint(effectiveSpec.version),
			requiredBy = rootPackageName,
			aliasedAs = if dependencyAlias ~= effectiveSpec.name then dependencyAlias else nil,
		}

		table.insert(state.rootRegistryAliases, { alias = dependencyAlias, name = registryPackageName })
		return
	end

	state.dependencies[dependencyAlias] = getKey(effectiveSpec)
	table.insert(state.queue, {
		spec = effectiveSpec,
		includeDev = includeDev and effectiveSpec.sourceKind == "path",
	})
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
		collectRootDependency(
			state,
			rootManifest.package.name or "<virtual root>",
			dependencyAlias,
			dependencySpec,
			rootManifest.registry,
			rootManifest.overrides,
			rootManifest.package.name == nil and not excludeDev
		)
	end

	if not excludeDev then
		for dependencyAlias, dependencySpec in rootManifest.package.devDependencies do
			collectRootDependency(
				state,
				rootManifest.package.name or "<virtual root>",
				dependencyAlias,
				dependencySpec,
				rootManifest.registry,
				rootManifest.overrides,
				rootManifest.package.name == nil and not excludeDev
			)
		end
	end

	return state
end

local function queueSourceOverrides(state: ResolutionState, overrides: { [string]: manifest.DependencySpec })
	local names: { string } = {}
	for name, spec in overrides do
		if spec.sourceKind ~= "registry" then
			table.insert(names, name)
		end
	end
	table.sort(names)

	for _, name in names do
		table.insert(state.queue, { spec = overrides[name], includeDev = false })
	end
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
		local storeKey = if registryUrl then store.qualifyRegistryKey(key, registryUrl) else key

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
		local req = state.registryRequirements[rootAlias.alias]
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
	local overrides = rootManifest.overrides
	queueSourceOverrides(state, overrides)
	processSourceQueue(state, rootDirectory, overrides, rootManifest.registry)

	resolveRegistryDependencies(state, universe, overrides, lockedRegistryVersions)

	return buildLockfile(state, overrides, lockfilePath, rootManifest.registry)
end

return {
	resolve = resolve,
}
