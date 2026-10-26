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
		target = if #target.parts == 0
			then nil
			else path.posix.format({
				parts = target.parts,
				absolute = false,
			}),
	} :: manifest.GitHubDependencySpec)
end

local function fetchSource(spec: manifest.DependencySpec): SourceLocation
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
		return path.posix.format({
			parts = path.relative(rootDirectory, selectedPath).parts,
			absolute = false,
		})
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
	read dev: boolean,
}

type ResolutionState = {
	queue: { manifest.DependencySpec },
	queueIndex: number,
	dependencies: { [string]: string },
	devDependencies: { [string]: string },
	packages: { [string]: lockfile.LockfileDependency },
	registryRequirements: { [string]: semver.Requirement },
	-- Maps a source-qualified package identity to its name in the registry.
	registrySources: { [string]: string },
	-- Maps an unqualified registry package name to all source-qualified identities seen for it.
	registryIdentitiesBySource: { [string]: { [string]: boolean } },
	rootRegistryAliases: { RootRegistryAlias },
	-- Requirements are retained until registry resolution so dependency edges can
	-- target the solver-selected compatibility slot rather than a package name.
	unresolvedRegistryDependencies: { [string]: { [string]: semver.Requirement } },
	openDependencies: { [string]: { [string]: string } },
	unresolvedRegistryDevDependencies: { [string]: { [string]: semver.Requirement } },
	openDevDependencies: { [string]: { [string]: string } },
	registryUrlByPackage: { [string]: string },
	memberKeys: { [string]: boolean },
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

local function getMemberKeys(
	rootManifest: manifest.ProjectManifest,
	overrides: { [string]: manifest.DependencySpec }
): { [string]: boolean }
	local members: { [string]: boolean } = {}
	if rootManifest.package.name ~= nil then
		return members
	end

	for _, section in { rootManifest.package.dependencies, rootManifest.package.devDependencies } do
		for _, spec in section do
			if spec.sourceKind ~= "path" then
				continue
			end
			local effectiveSpec = overrides[spec.name] or spec
			if effectiveSpec.sourceKind == "path" then
				members[getKey(effectiveSpec)] = true
			end
		end
	end

	return members
end

-- Registry overrides may replace one package name with another. Follow those
-- replacements to reject cycles up front.
local function assertNoRegistryOverrideCycles(overrides: { [string]: manifest.DependencySpec })
	local names: { string } = {}
	for name, spec in overrides do
		if spec.sourceKind == "registry" then
			table.insert(names, name)
		end
	end
	table.sort(names)

	local visited: { [string]: boolean } = {}
	for _, start in names do
		if visited[start] then
			continue
		end

		local chain: { string } = {}
		local positions: { [string]: number } = {}
		local current = start
		while true do
			if positions[current] then
				local cycle: { string } = {}
				for i = positions[current], #chain do
					table.insert(cycle, chain[i])
				end
				table.insert(cycle, current)
				error(`Registry override cycle: {table.concat(cycle, " -> ")}`)
			end

			if visited[current] then
				break
			end
			visited[current] = true
			positions[current] = #chain + 1
			table.insert(chain, current)

			local spec = overrides[current]
			if spec == nil or spec.sourceKind ~= "registry" or spec.name == current then
				break
			end
			current = spec.name
		end
	end
end

local function collectSourcePackageDependencies(
	key: string,
	location: SourceLocation,
	overrides: { [string]: manifest.DependencySpec },
	rootRegistryUrl: string?,
	transitiveDependencies: { [string]: string },
	transitiveDevDependencies: { [string]: string }?,
	queue: { manifest.DependencySpec },
	registryRequirements: { [string]: semver.Requirement },
	registrySources: { [string]: string },
	registryIdentitiesBySource: { [string]: { [string]: boolean } },
	unresolvedRegistryDependencies: { [string]: { [string]: semver.Requirement } },
	unresolvedRegistryDevDependencies: { [string]: { [string]: semver.Requirement } },
	registryUrlByPackage: { [string]: string }
)
	local nestedManifestPath = getManifestPath(location.directory)
	if not fs.exists(nestedManifestPath) then
		error(`Package '{key}' does not contain a manifest: {nestedManifestPath}`)
	end

	local dependencyManifest = manifest.parseFile(nestedManifestPath)
	assertNotVirtualPackage(key, dependencyManifest)

	local function collectDependencies(
		dependencies: { [string]: manifest.DependencySpec },
		targetDependencies: { [string]: string },
		targetUnresolvedRegistryDependencies: { [string]: { [string]: semver.Requirement } }
	)
		for dependencyAlias, dependencySpec in dependencies do
			local sourceSpec = resolveDependencySource(dependencySpec, location)
			local overrideSpec = overrides[sourceSpec.name]
			local effectiveSpec = overrideSpec or sourceSpec

			if effectiveSpec.sourceKind == "registry" and overrideSpec == nil then
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

				local requirement: semver.Requirement = table.freeze({
					name = registryPackageName,
					constraint = semver.parseConstraint(effectiveSpec.version),
					requiredBy = key,
					aliasedAs = if dependencyAlias ~= effectiveSpec.name then dependencyAlias else nil,
				})
				registryRequirements[`{key}:{dependencyAlias}`] = requirement

				if not targetUnresolvedRegistryDependencies[key] then
					targetUnresolvedRegistryDependencies[key] = {}
				end

				targetUnresolvedRegistryDependencies[key][dependencyAlias] = requirement
			else
				targetDependencies[dependencyAlias] = getKey(effectiveSpec)
				table.insert(queue, effectiveSpec)
			end
		end
	end

	collectDependencies(dependencyManifest.package.dependencies, transitiveDependencies, unresolvedRegistryDependencies)
	if transitiveDevDependencies then
		collectDependencies(
			dependencyManifest.package.devDependencies,
			transitiveDevDependencies,
			unresolvedRegistryDevDependencies
		)
	end
end

local function resolveSourcePackage(
	spec: manifest.DependencySpec,
	rootDirectory: string,
	packages: { [string]: lockfile.LockfileDependency },
	openDependencies: { [string]: { [string]: string } },
	openDevDependencies: { [string]: { [string]: string } },
	queue: { manifest.DependencySpec },
	registryRequirements: { [string]: semver.Requirement },
	registrySources: { [string]: string },
	registryIdentitiesBySource: { [string]: { [string]: boolean } },
	unresolvedRegistryDependencies: { [string]: { [string]: semver.Requirement } },
	unresolvedRegistryDevDependencies: { [string]: { [string]: semver.Requirement } },
	registryUrlByPackage: { [string]: string },
	overrides: { [string]: manifest.DependencySpec },
	rootRegistryUrl: string?,
	memberKeys: { [string]: boolean },
	excludeDev: boolean
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
	local transitiveDevDependencies: { [string]: string }? = nil
	if memberKeys[key] and not excludeDev then
		transitiveDevDependencies = {}
		openDevDependencies[key] = transitiveDevDependencies
	end

	local location = fetchSource(spec)

	collectSourcePackageDependencies(
		key,
		location,
		overrides,
		rootRegistryUrl,
		transitiveDependencies,
		transitiveDevDependencies,
		queue,
		registryRequirements,
		registrySources,
		registryIdentitiesBySource,
		unresolvedRegistryDependencies,
		unresolvedRegistryDevDependencies,
		registryUrlByPackage
	)

	packages[key] = table.freeze({
		name = spec.name,
		rev = if spec.sourceKind == "github" then spec.rev else nil,
		source = if spec.sourceKind == "path"
			then path.posix.format({
				parts = path.relative(rootDirectory, spec.directory).parts,
				absolute = false,
			})
			else spec.source,
		sourceKind = spec.sourceKind,
		target = if spec.sourceKind == "github" then spec.target else nil,
		installPath = getSourceInstallPath(spec, rootDirectory, location.directory),
		dependencies = transitiveDependencies,
		devDependencies = transitiveDevDependencies,
		registry = nil,
	})

	return key
end

local function processSourceQueue(
	state: ResolutionState,
	rootDirectory: string,
	overrides: { [string]: manifest.DependencySpec },
	rootRegistryUrl: string?,
	excludeDev: boolean
)
	while state.queueIndex <= #state.queue do
		local spec = state.queue[state.queueIndex]
		state.queueIndex += 1

		resolveSourcePackage(
			spec,
			rootDirectory,
			state.packages,
			state.openDependencies,
			state.openDevDependencies,
			state.queue,
			state.registryRequirements,
			state.registrySources,
			state.registryIdentitiesBySource,
			state.unresolvedRegistryDependencies,
			state.unresolvedRegistryDevDependencies,
			state.registryUrlByPackage,
			overrides,
			rootRegistryUrl,
			state.memberKeys,
			excludeDev
		)
	end
end

local function buildEffectiveUniverse(
	universe: semver.Universe,
	overrides: { [string]: manifest.DependencySpec },
	registrySources: { [string]: string },
	registryOverrideTargets: { [string]: { name: string, constraint: semver.Constraint } }
): (semver.Universe, { [string]: { [string]: string } })
	local sourceOverrideNames: { [string]: boolean } = {}
	for name, spec in overrides do
		if spec.sourceKind ~= "registry" then
			sourceOverrideNames[name] = true
		end
	end

	local effective: semver.Universe = {}
	local sourceOverridedDeps: { [string]: { [string]: string } } = {}

	for pkgName, versions in universe do
		local sourceName = registrySources[pkgName] or pkgName

		local registryOverride = registryOverrideTargets[sourceName]

		-- path/git overrides shouldn't enter the solver
		if sourceOverrideNames[sourceName] then
			continue
		end
		-- registry override skip non-target package identities
		if registryOverride and pkgName ~= registryOverride.name then
			continue
		end

		-- filter version candidates to match registry override
		local candidates = versions
		if registryOverride then
			candidates = {}
			for _, version in versions do
				if semver.satisfies(version.version, registryOverride.constraint) then
					table.insert(candidates, version)
				end
			end
			assert(
				#candidates > 0,
				`Override constrains '{sourceName}' to {semver.formatConstraint(registryOverride.constraint)}, but no matching version exists in the registry`
			)
		end
		-- continue processing
		local rewritten: { semver.PackageVersion } = {}
		for _, version in candidates do
			local newDeps: { [string]: semver.Requirement } = {}
			for alias, dep in version.dependencies do
				local dependencySource = registrySources[dep.name] or dep.name
				-- rewrite child dependency edges
				local dependencyRegistryOverride = registryOverrideTargets[dependencySource]
				if dependencyRegistryOverride then
					newDeps[alias] = table.freeze({
						name = dependencyRegistryOverride.name,
						constraint = dependencyRegistryOverride.constraint,
						requiredBy = dep.requiredBy,
						aliasedAs = dep.aliasedAs,
					})
				elseif sourceOverrideNames[dependencySource] then
					local vKey = `{version.name}@{version.versionString}`
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
					name = version.name,
					version = version.version,
					versionString = version.versionString,
					dependencies = table.freeze(newDeps),
				})
			)
		end
		effective[pkgName] = rewritten
	end

	return effective, sourceOverridedDeps
end

local function aliasesAreStale(
	lock: lockfile.Lockfile,
	recorded: { [string]: string },
	expected: { [string]: manifest.DependencySpec },
	rootDirectory: string,
	overrides: { [string]: manifest.DependencySpec },
	rootRegistryUrl: string?,
	packageRegistryUrl: string?
): boolean
	for alias in expected do
		if recorded[alias] == nil then
			return true
		end
	end
	for alias in recorded do
		if expected[alias] == nil then
			return true
		end
	end
	for alias, declaredSpec in expected do
		local overrideSpec = overrides[declaredSpec.name]
		local depSpec = overrideSpec or declaredSpec
		local recordedPkg = lock.packages[recorded[alias]]
		if recordedPkg == nil or not lockfile.isSameSource(recordedPkg, depSpec, rootDirectory) then
			return true
		end
		if depSpec.sourceKind == "registry" then
			local registryUrl = if overrideSpec then rootRegistryUrl else packageRegistryUrl
			local constraint = semver.parseConstraint(depSpec.version)
			local lockedVersion = semver.tryParse(recordedPkg.rev :: string)
			if
				recordedPkg.source ~= depSpec.source
				or not registryUrlUtil.equals(recordedPkg.registry, registryUrl)
				or lockedVersion == nil
				or not semver.satisfies(lockedVersion, constraint)
			then
				return true
			end
		end
	end
	return false
end

local function pathDepsAreStale(
	lock: lockfile.Lockfile,
	rootDirectory: string,
	overrides: { [string]: manifest.DependencySpec },
	rootRegistryUrl: string?,
	rootLocalDevPackageKeys: { [string]: boolean }
): (boolean, string?)
	for key, pkg in lock.packages do
		if pkg.sourceKind ~= "path" then
			continue
		end
		local packageInstallPath = path.format(path.join(rootDirectory, pkg.installPath))
		local depManifestPath = path.format(path.join(packageInstallPath, "loom.config.luau"))
		if not fs.exists(depManifestPath) then
			return true, `path dependency '{pkg.name}' has no manifest`
		end
		local ok, depManifest = pcall(manifest.parseFile, depManifestPath)
		if not ok then
			return true, `path dependency '{pkg.name}' has an invalid manifest`
		end
		if
			aliasesAreStale(
				lock,
				pkg.dependencies,
				depManifest.package.dependencies,
				rootDirectory,
				overrides,
				rootRegistryUrl,
				depManifest.registry
			)
		then
			return true, `path dependency '{pkg.name}' dependencies have changed`
		end
		if
			rootLocalDevPackageKeys[key]
			and aliasesAreStale(
				lock,
				pkg.devDependencies or {},
				depManifest.package.devDependencies,
				rootDirectory,
				overrides,
				rootRegistryUrl,
				depManifest.registry
			)
		then
			return true, `path dependency '{pkg.name}' dev dependencies have changed`
		end
	end
	return false, nil
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
		if satisfied then
			local pathsAreStale
			pathsAreStale, reason = pathDepsAreStale(
				existingLock,
				rootDirectory,
				rootManifest.overrides,
				rootManifest.registry,
				if excludeDev then {} else getMemberKeys(rootManifest, rootManifest.overrides)
			)
			satisfied = not pathsAreStale
		end

		if options and options.locked then
			if not satisfied then
				error(`--locked: lockfile does not satisfy manifest ({reason}). Run \`lute pkg install\` to update.`)
			end
			return existingLock, nil
		end

		if satisfied then
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
	isDev: boolean
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

		table.insert(state.rootRegistryAliases, { alias = dependencyAlias, name = registryPackageName, dev = isDev })
		return
	end

	local rootDependencies = if isDev then state.devDependencies else state.dependencies
	rootDependencies[dependencyAlias] = getKey(effectiveSpec)
	table.insert(state.queue, effectiveSpec)
end

local function collectRootDependencies(
	rootManifest: manifest.ProjectManifest,
	overrides: { [string]: manifest.DependencySpec },
	excludeDev: boolean
): ResolutionState
	local state: ResolutionState = {
		queue = {},
		queueIndex = 1,
		dependencies = {},
		devDependencies = {},
		packages = {},
		registryRequirements = {},
		registrySources = {},
		registryIdentitiesBySource = {},
		rootRegistryAliases = {},
		unresolvedRegistryDependencies = {},
		openDependencies = {},
		unresolvedRegistryDevDependencies = {},
		openDevDependencies = {},
		registryUrlByPackage = {},
		memberKeys = getMemberKeys(rootManifest, overrides),
	}

	for dependencyAlias, dependencySpec in rootManifest.package.dependencies do
		collectRootDependency(
			state,
			rootManifest.package.name or "<virtual root>",
			dependencyAlias,
			dependencySpec,
			rootManifest.registry,
			overrides,
			false
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
				overrides,
				true
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
		table.insert(state.queue, overrides[name])
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

-- Identify registry overrides whose original package appears in current universe
local function getActiveRegistryOverrides(
	universe: semver.Universe,
	overrides: { [string]: manifest.DependencySpec },
	registrySources: { [string]: string }
): { [string]: manifest.RegistryDependencySpec }
	local active: { [string]: manifest.RegistryDependencySpec } = {}
	for packageName in universe do
		local sourceName = registrySources[packageName] or packageName
		local spec = overrides[sourceName]
		if spec and spec.sourceKind == "registry" then
			active[sourceName] = spec
		end
	end
	return active
end

-- Fetch replacement package froom root registry/.
local function fetchActiveRegistryOverrideTargets(
	universe: semver.Universe,
	state: ResolutionState,
	overrides: { [string]: manifest.DependencySpec },
	rootRegistryUrl: string?
)
	local active = getActiveRegistryOverrides(universe, overrides, state.registrySources)
	if next(active) == nil then
		return
	end

	assert(rootRegistryUrl ~= nil, "Registry overrides require a 'registry' field in the root manifest.")

	local names: { string } = {}
	for name in active do
		table.insert(names, name)
	end
	table.sort(names)

	for _, name in names do
		local spec = active[name]
		local targetName = registerRegistryPackage(
			state.registrySources,
			state.registryIdentitiesBySource,
			state.registryUrlByPackage,
			spec.name,
			rootRegistryUrl
		)
		if universe[targetName] == nil then
			local partial = registry.fetchUniverse(rootRegistryUrl, { { name = spec.name, source = spec.source } })
			local namespaced = namespaceRegistryUniverse(partial, rootRegistryUrl, state)
			for packageName, versions in namespaced do
				universe[packageName] = versions
			end
		end
	end
end

-- Manifest specs use unqualified registry names. The solver needs the target's
-- source-qualified identity and parsed version constraint after registration.
local function getRegistryOverrideTargets(
	state: ResolutionState,
	overrides: { [string]: manifest.DependencySpec },
	rootRegistryUrl: string?
): { [string]: { name: string, constraint: semver.Constraint } }
	local targets: { [string]: { name: string, constraint: semver.Constraint } } = {}
	for name, spec in overrides do
		if spec.sourceKind == "registry" then
			targets[name] = {
				name = registerRegistryPackage(
					state.registrySources,
					state.registryIdentitiesBySource,
					state.registryUrlByPackage,
					spec.name,
					rootRegistryUrl
				),
				constraint = semver.parseConstraint(spec.version),
			}
		end
	end
	return targets
end

local function resolveRegistryDependencies(
	state: ResolutionState,
	universe: semver.Universe?,
	overrides: { [string]: manifest.DependencySpec },
	lockedRegistryVersions: { [string]: string }?,
	rootRegistryUrl: string?
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

	if universe == nil then
		-- this is the path normally
		fetchActiveRegistryOverrideTargets(effectiveUniverse, state, overrides, rootRegistryUrl)
	elseif
		rootRegistryUrl and next(getActiveRegistryOverrides(effectiveUniverse, overrides, state.registrySources))
	then
		-- this is only for tests (normal production instillation does not pass in a universe)
		local namespaced = namespaceRegistryUniverse(universe, rootRegistryUrl, state)
		for name, versions in namespaced do
			effectiveUniverse[name] = versions
		end
	end

	-- Build a modified universe that respects overrides.
	if next(overrides) ~= nil then
		local registryOverrideTargets = getRegistryOverrideTargets(state, overrides, rootRegistryUrl)
		effectiveUniverse, sourceOverridedDeps =
			buildEffectiveUniverse(effectiveUniverse, overrides, state.registrySources, registryOverrideTargets)
	end

	local resolution = semver.solve(effectiveUniverse, state.registryRequirements, lockedRegistryVersions)

	-- Look up the solver-selected version for a dependency's compatibility slot.
	local function getResolvedVersion(requirement: semver.Requirement): semver.PackageVersion
		local slotKey = semver.getSlotKey(requirement.name, requirement.constraint, effectiveUniverse)
		local pkgVersion = resolution[slotKey]
		assert(pkgVersion ~= nil, `Solver did not resolve registry dependency '{requirement.name}' in slot '{slotKey}'`)
		return pkgVersion
	end

	for _, pkgVersion in resolution do
		local registryPackageName = pkgVersion.name
		local key = getRegistryLockKey(state, registryPackageName, pkgVersion.versionString)
		local registryUrl = state.registryUrlByPackage[registryPackageName]
		local storeKey = if registryUrl then store.qualifyRegistryKey(key, registryUrl) else key

		local transitiveDependencies: { [string]: string } = {}
		for alias, dependency in pkgVersion.dependencies do
			local resolvedVersion = getResolvedVersion(dependency)

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
			target = nil,
			installPath = store.toStorePath(storeKey),
			dependencies = table.freeze(transitiveDependencies),
			devDependencies = nil,
			registry = registryUrl,
		})
	end

	-- Fill in pending registry dependency keys directly into the unversioned packages' dependency tables.
	for pkgKey, unresolvedAliases in state.unresolvedRegistryDependencies do
		local packageDependencies = state.openDependencies[pkgKey]
		for dependencyAlias, requirement in unresolvedAliases do
			local pkgVersion = getResolvedVersion(requirement)
			packageDependencies[dependencyAlias] = getRegistryLockKey(state, requirement.name, pkgVersion.versionString)
		end
	end
	for pkgKey, unresolvedAliases in state.unresolvedRegistryDevDependencies do
		local packageDependencies = state.openDevDependencies[pkgKey]
		for dependencyAlias, requirement in unresolvedAliases do
			local pkgVersion = getResolvedVersion(requirement)
			packageDependencies[dependencyAlias] = getRegistryLockKey(state, requirement.name, pkgVersion.versionString)
		end
	end

	-- Write root-level registry dependency aliases now that versions are resolved.
	for _, rootAlias in state.rootRegistryAliases do
		local req = state.registryRequirements[rootAlias.alias]
		if req == nil then
			continue
		end
		local pkgVersion = getResolvedVersion(req)
		local rootDependencies = if rootAlias.dev then state.devDependencies else state.dependencies
		rootDependencies[rootAlias.alias] = getRegistryLockKey(state, req.name, pkgVersion.versionString)
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
	for _, packageDependencies in state.openDevDependencies do
		table.freeze(packageDependencies)
	end

	table.freeze(state.packages)
	table.freeze(state.dependencies)
	local frozenDevDependencies: { [string]: string }? = if next(state.devDependencies)
		then table.freeze(state.devDependencies)
		else nil

	local serializedOverrides = lockfile.serializeOverrides(overrides)
	local frozenOverrides: { [string]: string }? = if next(serializedOverrides)
		then table.freeze(serializedOverrides)
		else nil

	local lock: lockfile.Lockfile = table.freeze({
		version = 4,
		packages = state.packages,
		dependencies = state.dependencies,
		devDependencies = frozenDevDependencies,
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
	assertNoRegistryOverrideCycles(rootManifest.overrides)

	local reusedLock, lockedRegistryVersions =
		tryReuseLockfile(rootManifest, lockfilePath, rootDirectory, excludeDev, options)
	if reusedLock then
		return reusedLock
	end

	local overrides = rootManifest.overrides
	local state = collectRootDependencies(rootManifest, overrides, excludeDev)
	queueSourceOverrides(state, overrides)
	processSourceQueue(state, rootDirectory, overrides, rootManifest.registry, excludeDev)

	resolveRegistryDependencies(state, universe, overrides, lockedRegistryVersions, rootManifest.registry)

	return buildLockfile(state, overrides, lockfilePath, rootManifest.registry)
end

return {
	resolve = resolve,
}
