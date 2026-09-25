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
local workspace = require("./workspace")

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
	local normalizedSpec, missingPath = lockfile.tryNormalizePathDependency(spec, installPath, rootDirectory)
	if normalizedSpec == nil then
		assert(missingPath ~= nil)
		error(`Path dependency directory not found: {missingPath} (for package '{spec.name}')`)
	end

	return normalizedSpec
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
	read member: string,
	read alias: string,
	read requirementKey: string,
}

type RegistryRequirementCollection = {
	items: { [string]: semver.Requirement },
	nextIndex: number,
}

type ResolutionState = {
	queue: { manifest.DependencySpec },
	queueIndex: number,
	dependencies: { [string]: { [string]: string } },
	packages: { [string]: lockfile.LockfileDependency },
	registryRequirements: RegistryRequirementCollection,
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

local function addRegistryRequirement(
	registryRequirements: RegistryRequirementCollection,
	requirement: semver.Requirement
): string
	local key = `registry-requirement:{registryRequirements.nextIndex}`
	registryRequirements.nextIndex += 1
	registryRequirements.items[key] = requirement
	return key
end

type SourcePackage = {
	directory: string,
	package: manifest.PackageManifest,
	registryUrl: string?,
	workspaceRoot: string?,
	workspaceDefaultMember: string?,
	workspaceMemberDirectories: { [string]: boolean }?,
}

local function collectWorkspaceMemberDirectories(resolvedWorkspace: workspace.Workspace): { [string]: boolean }
	local directories: { [string]: boolean } = {}
	for _, member in resolvedWorkspace.members do
		directories[member.directory] = true
	end
	return directories
end

local function findWorkspaceMemberAtDirectory(
	resolvedWorkspace: workspace.Workspace,
	directory: string
): workspace.Member?
	for _, member in resolvedWorkspace.members do
		if member.directory == directory then
			return member
		end
	end
	return nil
end

local function findWorkspaceMemberByName(resolvedWorkspace: workspace.Workspace, name: string): workspace.Member?
	for _, member in resolvedWorkspace.members do
		if member.name == name then
			return member
		end
	end
	return nil
end

local function getSourcePackage(
	spec: manifest.DependencySpec,
	sourceDirectory: string,
	workspaceResolver: workspace.WorkspaceResolver
): SourcePackage
	local resolvedWorkspace = workspaceResolver:findResolvedRoot(sourceDirectory)
	local workspaceRoot = resolvedWorkspace.rootDirectory
	local workspaceManifest = resolvedWorkspace.rootManifest
	local member = if spec.sourceKind == "github"
		then findWorkspaceMemberByName(resolvedWorkspace, spec.name)
		else findWorkspaceMemberAtDirectory(resolvedWorkspace, sourceDirectory)
	if member == nil and sourceDirectory == workspaceRoot and workspaceManifest.workspace then
		local defaultMember = workspaceManifest.workspace.defaultMember
		if defaultMember then
			member = findWorkspaceMemberByName(resolvedWorkspace, defaultMember)
		end
	end

	if spec.sourceKind == "github" then
		assert(member ~= nil, `Git dependency '{spec.source}' does not contain package '{spec.name}'`)
	end

	if member then
		return {
			directory = member.directory,
			package = member.package,
			registryUrl = resolvedWorkspace.registry,
			workspaceRoot = workspaceRoot,
			workspaceDefaultMember = if workspaceManifest.workspace
				then workspaceManifest.workspace.defaultMember
				else nil,
			workspaceMemberDirectories = collectWorkspaceMemberDirectories(resolvedWorkspace),
		}
	end

	local sourceManifest = manifest.parseFile(getManifestPath(sourceDirectory))
	local sourcePackage = sourceManifest.package
	assert(sourcePackage ~= nil, `Source package '{sourceDirectory}' must declare a package`)
	return {
		directory = sourceDirectory,
		package = sourcePackage,
		registryUrl = sourceManifest.registry,
	}
end

local function normalizeSourceDependency(
	dependencySpec: manifest.DependencySpec,
	sourcePackage: SourcePackage,
	rootDirectory: string,
	githubSpec: manifest.GitHubDependencySpec?
): manifest.DependencySpec
	local normalizedSpec = normalizePathDependency(dependencySpec, sourcePackage.directory, rootDirectory)
	if githubSpec == nil or dependencySpec.sourceKind ~= "path" then
		return normalizedSpec
	end

	local sourcePath = path.format(path.resolve(sourcePackage.directory, dependencySpec.source))
	local isWorkspaceMember = sourcePackage.workspaceMemberDirectories
		and sourcePackage.workspaceMemberDirectories[sourcePath]
	local isWorkspaceRootDefaultMember = sourcePackage.workspaceRoot == sourcePath
		and sourcePackage.workspaceDefaultMember ~= nil
	if isWorkspaceMember or isWorkspaceRootDefaultMember then
		return table.freeze({
			name = dependencySpec.name,
			sourceKind = "github" :: "github",
			source = githubSpec.source,
			rev = githubSpec.rev,
		})
	end

	return normalizedSpec
end

local function collectSourcePackageDependencies(
	key: string,
	sourcePackage: SourcePackage,
	rootDirectory: string,
	overrides: { [string]: manifest.DependencySpec },
	rootRegistryUrl: string?,
	githubSpec: manifest.GitHubDependencySpec?,
	transitiveDependencies: { [string]: string },
	queue: { manifest.DependencySpec },
	registryRequirements: RegistryRequirementCollection,
	registrySources: { [string]: string },
	registryIdentitiesBySource: { [string]: { [string]: boolean } },
	unresolvedRegistryDependencies: { [string]: { [string]: string } },
	registryUrlByPackage: { [string]: string }
)
	for dependencyAlias, dependencySpec in sourcePackage.package.dependencies do
		local normalizedSpec = normalizeSourceDependency(dependencySpec, sourcePackage, rootDirectory, githubSpec)
		local overrideSpec = overrides[normalizedSpec.name]
		local effectiveSpec = overrideSpec or normalizedSpec

		if normalizedSpec.sourceKind == "registry" then
			assert(
				sourcePackage.registryUrl ~= nil,
				`Package '{key}' has registry dependency '{normalizedSpec.name}' but no 'registry' field in its manifest.`
			)
		end

		if effectiveSpec.sourceKind == "registry" then
			local effectiveRegistryUrl = if overrideSpec then rootRegistryUrl else sourcePackage.registryUrl
			local registryPackageName = registerRegistryPackage(
				registrySources,
				registryIdentitiesBySource,
				registryUrlByPackage,
				effectiveSpec.name,
				effectiveRegistryUrl
			)

			addRegistryRequirement(registryRequirements, {
				name = registryPackageName,
				constraint = semver.parseConstraint(effectiveSpec.version),
				requiredBy = key,
				aliasedAs = if dependencyAlias ~= effectiveSpec.name then dependencyAlias else nil,
			})

			if not unresolvedRegistryDependencies[key] then
				unresolvedRegistryDependencies[key] = {}
			end

			unresolvedRegistryDependencies[key][dependencyAlias] = registryPackageName
		else
			transitiveDependencies[dependencyAlias] = getKey(effectiveSpec)
			table.insert(queue, effectiveSpec)
		end
	end
end

local function resolveSourcePackage(
	spec: manifest.DependencySpec,
	rootDirectory: string,
	packages: { [string]: lockfile.LockfileDependency },
	openDependencies: { [string]: { [string]: string } },
	queue: { manifest.DependencySpec },
	registryRequirements: RegistryRequirementCollection,
	registrySources: { [string]: string },
	registryIdentitiesBySource: { [string]: { [string]: boolean } },
	unresolvedRegistryDependencies: { [string]: { [string]: string } },
	registryUrlByPackage: { [string]: string },
	overrides: { [string]: manifest.DependencySpec },
	rootRegistryUrl: string?,
	workspaceResolver: workspace.WorkspaceResolver
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

	local sourceDirectory = fetchSource(spec, rootDirectory)
	local sourcePackage = getSourcePackage(spec, sourceDirectory, workspaceResolver)

	collectSourcePackageDependencies(
		key,
		sourcePackage,
		rootDirectory,
		overrides,
		rootRegistryUrl,
		if spec.sourceKind == "github" then spec else nil,
		transitiveDependencies,
		queue,
		registryRequirements,
		registrySources,
		registryIdentitiesBySource,
		unresolvedRegistryDependencies,
		registryUrlByPackage
	)

	local installPath: string
	if spec.sourceKind == "path" then
		installPath = path.format(path.relative(rootDirectory, sourcePackage.directory))
	else
		local memberRelativePath = path.relative(sourceDirectory, sourcePackage.directory)
		if #memberRelativePath.parts == 0 then
			installPath = store.toStorePath(key)
		else
			installPath = path.format(path.join(store.toStorePath(key), memberRelativePath))
		end
	end

	packages[key] = table.freeze({
		name = spec.name,
		rev = if spec.sourceKind == "github" then spec.rev else nil,
		source = spec.source,
		sourceKind = spec.sourceKind,
		installPath = installPath,
		dependencies = transitiveDependencies,
	})

	return key
end

local function processSourceQueue(
	state: ResolutionState,
	rootDirectory: string,
	overrides: { [string]: manifest.DependencySpec },
	rootRegistryUrl: string?,
	workspaceResolver: workspace.WorkspaceResolver
)
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
			state.registryUrlByPackage,
			overrides,
			rootRegistryUrl,
			workspaceResolver
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
	workspaceResolver: workspace.WorkspaceResolver
): boolean
	for _, pkg in lock.packages do
		if pkg.sourceKind ~= "path" then
			continue
		end

		local packageSourcePath = path.format(path.resolve(rootDirectory, pkg.source))
		local ok, result = pcall(getSourcePackage, {
			name = pkg.name,
			sourceKind = "path" :: "path",
			source = pkg.source,
		}, packageSourcePath, workspaceResolver)
		if not ok then
			return true
		end
		local sourcePackage = result :: SourcePackage
		local expectedInstallPath = path.format(path.relative(rootDirectory, sourcePackage.directory))
		if pkg.installPath ~= expectedInstallPath then
			return true
		end
		local depPackage = sourcePackage.package

		for alias in depPackage.dependencies do
			if pkg.dependencies[alias] == nil then
				return true
			end
		end

		for alias in pkg.dependencies do
			if depPackage.dependencies[alias] == nil then
				return true
			end
		end

		for alias, depSpec in depPackage.dependencies do
			local normalizeOk, normalizedDepSpec =
				pcall(normalizePathDependency, depSpec, sourcePackage.directory, rootDirectory)
			if not normalizeOk then
				return true
			end
			local overrideSpec = overrides[(normalizedDepSpec :: manifest.DependencySpec).name]
			depSpec = overrideSpec or normalizedDepSpec

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
				local registryUrl = if overrideSpec then rootRegistryUrl else sourcePackage.registryUrl
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

local function tryReuseLockfile(
	rootWorkspace: workspace.Workspace,
	lockfilePath: string,
	rootDirectory: string,
	excludeDev: boolean,
	options: ResolveOptions?,
	workspaceResolver: workspace.WorkspaceResolver
): (lockfile.Lockfile?, { [string]: string }?)
	local existingLock = lockfile.tryParseFile(lockfilePath)

	if options and options.locked and existingLock == nil then
		error("--locked: no lockfile found. Run `lute pkg install` first.")
	end

	if existingLock then
		local satisfied, reason = lockfile.satisfiesManifest(existingLock, rootWorkspace, excludeDev)

		if options and options.locked then
			if not satisfied then
				error(`--locked: lockfile does not satisfy manifest ({reason}). Run \`lute pkg install\` to update.`)
			end
			return existingLock, nil
		end

		if
			satisfied
			and not pathDepsAreStale(
				existingLock,
				rootDirectory,
				rootWorkspace.overrides,
				rootWorkspace.registry,
				workspaceResolver
			)
		then
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
	memberName: string,
	rootPackageName: string,
	dependencyAlias: string,
	dependencySpec: manifest.DependencySpec,
	registryUrl: string?,
	overrides: { [string]: manifest.DependencySpec }
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
		local requirementKey = addRegistryRequirement(state.registryRequirements, {
			name = registryPackageName,
			constraint = semver.parseConstraint(effectiveSpec.version),
			requiredBy = rootPackageName,
			aliasedAs = if dependencyAlias ~= effectiveSpec.name then dependencyAlias else nil,
		})

		table.insert(state.rootRegistryAliases, {
			member = memberName,
			alias = dependencyAlias,
			requirementKey = requirementKey,
		})
		return
	end

	state.dependencies[memberName][dependencyAlias] = getKey(effectiveSpec)
	table.insert(state.queue, effectiveSpec)
end

local function collectRootDependencies(rootWorkspace: workspace.Workspace, excludeDev: boolean): ResolutionState
	local state: ResolutionState = {
		queue = {},
		queueIndex = 1,
		dependencies = {},
		packages = {},
		registryRequirements = {
			items = {},
			nextIndex = 1,
		},
		registrySources = {},
		registryIdentitiesBySource = {},
		rootRegistryAliases = {},
		unresolvedRegistryDependencies = {},
		openDependencies = {},
		registryUrlByPackage = {},
	}

	for _, member in rootWorkspace.members do
		state.dependencies[member.name] = {}
		for dependencyAlias, dependencySpec in member.package.dependencies do
			local normalized = if rootWorkspace.overrides[dependencySpec.name]
				then dependencySpec
				else normalizePathDependency(dependencySpec, member.directory, rootWorkspace.rootDirectory)
			collectRootDependency(
				state,
				member.name,
				member.package.name,
				dependencyAlias,
				normalized,
				rootWorkspace.registry,
				rootWorkspace.overrides
			)
		end

		if not excludeDev then
			for dependencyAlias, dependencySpec in member.package.devDependencies do
				local normalized = if rootWorkspace.overrides[dependencySpec.name]
					then dependencySpec
					else normalizePathDependency(dependencySpec, member.directory, rootWorkspace.rootDirectory)
				collectRootDependency(
					state,
					member.name,
					member.package.name,
					dependencyAlias,
					normalized,
					rootWorkspace.registry,
					rootWorkspace.overrides
				)
			end
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

local function resolveRegistryDependencies(
	state: ResolutionState,
	universe: semver.Universe?,
	overrides: { [string]: manifest.DependencySpec },
	lockedRegistryVersions: { [string]: string }?
)
	-- Versioned dependency resolution: solve registry dependencies and stitch them into the package graph.
	if next(state.registryRequirements.items) == nil then
		return
	end

	-- Build or fetch the universe.
	local effectiveUniverse: semver.Universe
	local sourceOverridedDeps: { [string]: { [string]: string } } = {}

	if universe == nil then
		local packagesByRegistryUrl: { [string]: { { name: string, source: string } } } = {}
		local seen: { [string]: boolean } = {}

		for _, req in state.registryRequirements.items do
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
		for _, req in state.registryRequirements.items do
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

	local resolution = semver.solve(effectiveUniverse, state.registryRequirements.items, lockedRegistryVersions)

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
		local req = state.registryRequirements.items[rootAlias.requirementKey]
		if req == nil then
			continue
		end
		local pkgVersion = versionsByPackageName[req.name]
		assert(pkgVersion ~= nil, `Solver did not resolve root dependency '{req.name}'`)
		state.dependencies[rootAlias.member][rootAlias.alias] =
			getRegistryLockKey(state, req.name, pkgVersion.versionString)
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
	for _, dependencies in state.dependencies do
		table.freeze(dependencies)
	end
	table.freeze(state.dependencies)

	local serializedOverrides = lockfile.serializeOverrides(overrides)
	local frozenOverrides: { [string]: string }? = if next(serializedOverrides)
		then table.freeze(serializedOverrides)
		else nil

	local lock: lockfile.Lockfile = table.freeze({
		version = 4,
		packages = state.packages,
		dependencies = state.dependencies,
		overrides = frozenOverrides,
		registry = registryUrl,
	})

	fs.writeStringToFile(lockfilePath, `return {pp(lock)}\n`)

	return lock
end

local function resolve(
	rootWorkspace: workspace.Workspace,
	universe: semver.Universe?,
	options: ResolveOptions?
): lockfile.Lockfile
	local excludeDev = if options then options.excludeDev == true else false
	local rootDirectory = rootWorkspace.rootDirectory
	local lockfilePath = getLockfilePath(rootDirectory)
	local workspaceResolver = workspace.newWorkspaceResolver(rootWorkspace)

	local reusedLock, lockedRegistryVersions =
		tryReuseLockfile(rootWorkspace, lockfilePath, rootDirectory, excludeDev, options, workspaceResolver)
	if reusedLock then
		return reusedLock
	end

	local state = collectRootDependencies(rootWorkspace, excludeDev)
	local overrides = rootWorkspace.overrides
	queueSourceOverrides(state, overrides)
	processSourceQueue(state, rootDirectory, overrides, rootWorkspace.registry, workspaceResolver)

	resolveRegistryDependencies(state, universe, overrides, lockedRegistryVersions)

	return buildLockfile(state, overrides, lockfilePath, rootWorkspace.registry)
end

local function resolveFromDirectory(
	startDirectory: string,
	universe: semver.Universe?,
	options: ResolveOptions?
): lockfile.Lockfile
	return resolve(workspace.findResolvedRoot(startDirectory), universe, options)
end

return {
	resolve = resolve,
	resolveFromDirectory = resolveFromDirectory,
}
